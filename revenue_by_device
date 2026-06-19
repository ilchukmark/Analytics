WITH revenue_total AS (
 SELECT SUM(p.price) AS rt
 FROM DA.order AS o
 LEFT JOIN DA.product AS p ON p.item_id = o.item_id
),


all_continents AS (
 SELECT DISTINCT continent
 FROM DA.session_params
 WHERE continent IS NOT NULL
),


revenue_continent AS (
 SELECT
   sp.continent,
   SUM(p.price) AS continent_revenue
 FROM DA.order AS o
 LEFT JOIN DA.session AS s ON s.ga_session_id = o.ga_session_id
 LEFT JOIN DA.product AS p ON o.item_id = p.item_id
 LEFT JOIN DA.session_params AS sp ON sp.ga_session_id = s.ga_session_id
 GROUP BY 1
),


revenue_desktop AS (
 SELECT
   sp.continent,
   SUM(p.price) AS desktop_revenue_total
 FROM DA.session_params AS sp
 LEFT JOIN DA.order AS o ON o.ga_session_id = sp.ga_session_id
 LEFT JOIN DA.product AS p ON p.item_id = o.item_id
 WHERE sp.device = 'desktop'
 GROUP BY 1
),


revenue_mobile AS (
 SELECT
   sp.continent,
   SUM(p.price) AS mobile_revenue_total
 FROM DA.session_params AS sp
 LEFT JOIN DA.order AS o ON o.ga_session_id = sp.ga_session_id
 LEFT JOIN DA.product AS p ON p.item_id = o.item_id
 WHERE sp.device = 'mobile'
 GROUP BY 1
),


acc_metrics AS (
 SELECT
   sp.continent,
   COUNT(DISTINCT acc_s.account_id) AS account_cnt,
   COUNT(sp.ga_session_id) AS session_cnt
 FROM DA.session_params AS sp
 LEFT JOIN DA.account_session AS acc_s ON sp.ga_session_id = acc_s.ga_session_id
 GROUP BY 1
),


acc_metrics_verified AS (
 SELECT
   sp.continent,
   COUNT(DISTINCT acc_s.account_id) AS verified_account
 FROM DA.session_params AS sp
 LEFT JOIN DA.account_session AS acc_s ON sp.ga_session_id = acc_s.ga_session_id
 LEFT JOIN DA.account AS acc ON acc_s.account_id = acc.id
 WHERE acc.is_verified = 1
 GROUP BY 1
)


SELECT
 ac.continent AS Continent,
 rc.continent_revenue AS Revenue,
 rm.mobile_revenue_total AS `Revenue from Mobile`,
 rd.desktop_revenue_total AS `Revenue from Desktop`,
 CASE
   WHEN rt.rt = 0 THEN NULL
   ELSE (rc.continent_revenue / rt.rt) * 100
 END AS `% Revenue from Total`,
 am.account_cnt AS `Account Count`,
 amv.verified_account AS `Verified Account`,
 am.session_cnt AS `Session Count`
FROM all_continents AS ac
CROSS JOIN revenue_total AS rt
LEFT JOIN revenue_continent AS rc ON ac.continent = rc.continent
LEFT JOIN revenue_mobile AS rm ON ac.continent = rm.continent
LEFT JOIN revenue_desktop AS rd ON ac.continent = rd.continent
LEFT JOIN acc_metrics AS am ON ac.continent = am.continent
LEFT JOIN acc_metrics_verified AS amv ON ac.continent = amv.continent
ORDER BY Revenue DESC;
