WITH msg_metrics AS (
 SELECT
   es.id_account,
   DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS sent_date,
   DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH) AS sent_month,
   es.id_message
 FROM DA.account_session AS ash
 INNER JOIN DA.session AS s ON ash.ga_session_id = s.ga_session_id
 INNER JOIN DA.email_sent AS es ON ash.account_id = es.id_account
),


account_monthly_stats AS (
 SELECT
   sent_month,
   id_account,
   COUNT(id_message) AS msg_cnt_account,
   MIN(sent_date) AS first_sent_date,
   MAX(sent_date) AS last_sent_date
 FROM msg_metrics
 GROUP BY sent_month, id_account
),


total_monthly_stats AS (
 SELECT
   sent_month,
   COUNT(id_message) AS msg_cnt_total
 FROM msg_metrics
 GROUP BY sent_month
)


SELECT
 ams.sent_month,
 ams.id_account,
 (ams.msg_cnt_account / tms.msg_cnt_total) * 100 AS sent_msg_percent_from_this_month,
 ams.first_sent_date,
 ams.last_sent_date
FROM account_monthly_stats AS ams
INNER JOIN total_monthly_stats AS tms ON ams.sent_month = tms.sent_month
ORDER BY ams.last_sent_date DESC;
