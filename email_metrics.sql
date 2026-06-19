-- 1. Спочатку збираю базову інформацію по користувачах в CTE
-- Мені треба витягнути унікальні профілі, дізнатися точну дату, коли вони створили акаунт, і зачепити країну. Оскільки країна лежить в сесіях, я джойню таблиці сесій. Через ANY_VALUE беру країну саме з першої сесії (де мінімальна дата), щоб дані не дублювалися.
WITH account_base AS (
 SELECT
   acc.id AS account_id,
   acc.send_interval,
   acc.is_verified,
   acc.is_unsubscribed,
   MIN(DATE(ss.date)) AS account_created_date, 
   ANY_VALUE(sp.country HAVING MIN(ss.date)) AS country 
 FROM `DA.account` AS acc
 INNER JOIN `DA.account_session` AS acs ON acc.id = acs.account_id
 INNER JOIN `DA.session` AS ss ON acs.ga_session_id = ss.ga_session_id
 INNER JOIN `DA.session_params` AS sp ON sp.ga_session_id = ss.ga_session_id
 WHERE sp.country IS NOT NULL
 GROUP BY 1, 2, 3, 4
),


-- 2. Розраховую чисті метрики для самих акаунтів
-- Тут я групую дані за датою створення акаунта і всіма категоріями. Оскільки в цій частині ми рахуємо суто реєстрації, то метрики для емейлів (відправлені, відкриті, кліки) я просто забиваю нулями. Вони підтягнуться пізніше через UNION.
account_metrics AS (
 SELECT
   account_created_date AS date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   COUNT(DISTINCT account_id) AS account_cnt, 
   0 AS sent_msg,
   0 AS open_msg,
   0 AS visit_msg
 FROM account_base
 GROUP BY 1, 2, 3, 4, 5
),


-- 3. Готую дані по листах в CTE
email_events_deduplicated AS (
 SELECT
   sent.id_account,
   sent.id_message,
   sent.sent_date AS days_offset, -- Зміщення (через скільки днів після реєстрації відправили лист)
   1 AS is_sent,
   MAX(IF(ope.id_message IS NOT NULL, 1, 0)) AS is_opened,
   MAX(IF(vis.id_message IS NOT NULL, 1, 0)) AS is_visited
 FROM `DA.email_sent` AS sent
 LEFT JOIN `DA.email_open` AS ope
   ON sent.id_account = ope.id_account AND sent.id_message = ope.id_message
 LEFT JOIN `DA.email_visit` AS vis
   ON sent.id_account = vis.id_account AND sent.id_message = vis.id_message
 GROUP BY 1, 2, 3
),


-- 4. Рахую метрики для емейлів
-- Зв'язую листи з нашою базою акаунтів, щоб дізнатися профіль юзера (країну, статус підписки тощо)
email_metrics AS (
 SELECT
   DATE_ADD(ab.account_created_date, INTERVAL ev.days_offset DAY) AS date, -- Дата відправки листа
   ab.country,
   ab.send_interval,
   ab.is_verified,
   ab.is_unsubscribed,
   0 AS account_cnt,
   SUM(ev.is_sent) AS sent_msg,
   SUM(ev.is_opened) AS open_msg,
   SUM(ev.is_visited) AS visit_msg
 FROM email_events_deduplicated AS ev
 INNER JOIN account_base AS ab ON ev.id_account = ab.account_id
 GROUP BY 1, 2, 3, 4, 5
),


-- 5. Об'єдную два потоки через UNION ALL
combined_union AS (
 SELECT * FROM account_metrics
 UNION ALL
 SELECT * FROM email_metrics
),


-- 6. Рахую глобальні тотали по країнах через віконні функції
-- Щоб потім зробити рейтинг, мені треба знати загальну кількість акаунтів і листів по кожній країні. Використовую SUM() OVER(PARTITION BY country). Це дозволяє проставити загальну суму для країни в кожен рядок, не схлопуючи при цьому деталізацію по днях та статусах юзерів.
window_totals AS (
 SELECT
   date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   account_cnt,
   sent_msg,
   open_msg,
   visit_msg,
   SUM(account_cnt) OVER(PARTITION BY country) AS total_country_account_cnt,
   SUM(sent_msg) OVER(PARTITION BY country) AS total_country_sent_cnt
 FROM
   combined_union
),


-- 7. Нарізаю ранги (рейтинги) для країн
-- Сортую від більшого до меншого (DESC), щоб ТОП-1 отримали лідери ринку.
window_calculations AS (
 SELECT
   date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   account_cnt,
   sent_msg,
   open_msg,
   visit_msg,
   total_country_account_cnt,
   total_country_sent_cnt,
   DENSE_RANK() OVER(ORDER BY total_country_account_cnt DESC, country ASC) AS rank_total_country_account_cnt,
   DENSE_RANK() OVER(ORDER BY total_country_sent_cnt DESC, country ASC) AS rank_total_country_sent_cnt
 FROM
   window_totals
)


-- 8. Фінальний відбір даних
-- Залишаю в таблиці лише ті країни, які потрапили в ТОП-10 або за кількістю створених акаунтів або за кількістю відправлених листів. Усе, що нижче ТОП-10 — відсікається. Сортую для краси: спочатку найкращі країни за реєстраціями, а всередині країни — за свіжістю дат.
SELECT *
FROM window_calculations
WHERE
 rank_total_country_account_cnt <= 10
 OR rank_total_country_sent_cnt <= 10
ORDER BY
 rank_total_country_account_cnt ASC,
 date DESC;


-- Переглянути файл можна за посиланням: 
-- https://datastudio.google.com/reporting/89f9437e-4839-4eb9-a9cf-c77e15691a6b


