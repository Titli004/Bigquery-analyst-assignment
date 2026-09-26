# Q2(a)
--- "ARPDAU" is falling . Fix it.

-- OVERALL ARPDAU IN FIRST AND LAST 30 DAYS

WITH dau AS (
  SELECT PARSE_DATE('%Y%m%d', CAST(activity_date AS STRING)) AS activity_dt,
         COUNT(DISTINCT device_id) AS dau
  FROM `db.player_day`
  GROUP BY activity_dt
),
rev AS (
  SELECT DATE(event_ts) AS activity_dt, SUM(usd_amount) AS revenue
  FROM `db.purchase`
  GROUP BY activity_dt
),
daily AS (
  SELECT d.activity_dt, d.dau, COALESCE(r.revenue,0) AS revenue,
    CASE WHEN d.activity_dt BETWEEN '2026-01-01' AND '2026-01-30' THEN 'first_30'
         WHEN d.activity_dt BETWEEN '2026-04-01' AND '2026-04-30' THEN 'last_30' END AS period
  FROM dau d LEFT JOIN rev r USING (activity_dt)
)
SELECT period, SUM(revenue)/SUM(dau) AS arpdau, AVG(dau) AS avg_dau
FROM daily
WHERE period IS NOT NULL
GROUP BY period;

# -- SPLIT BY COUNTRY TIER
WITH pd AS (
  SELECT pd.device_id, PARSE_DATE('%Y%m%d', CAST(pd.activity_date AS STRING)) AS activity_dt,
         pp.country_tier
  FROM `db.player_day` pd
  JOIN `db.player_profile` pp USING(device_id)
),
dau AS (
  SELECT activity_dt, country_tier, COUNT(DISTINCT device_id) AS dau
  FROM pd GROUP BY 1,2
),
pur AS (
  SELECT DATE(pu.event_ts) AS activity_dt, pp.country_tier, pu.usd_amount
  FROM `db.purchase` pu
  JOIN `db.player_profile` pp USING(device_id)
),
rev AS (
  SELECT activity_dt, country_tier, SUM(usd_amount) AS revenue FROM pur GROUP BY 1,2
),
daily AS (
  SELECT d.activity_dt, d.country_tier, d.dau, COALESCE(r.revenue,0) AS revenue,
    CASE WHEN d.activity_dt BETWEEN '2026-01-01' AND '2026-01-30' THEN 'first_30'
         WHEN d.activity_dt BETWEEN '2026-04-01' AND '2026-04-30' THEN 'last_30' END AS period
  FROM dau d LEFT JOIN rev r USING(activity_dt, country_tier)
)
SELECT country_tier, period, SUM(revenue)/SUM(dau) AS arpdau, AVG(dau) AS avg_dau
FROM daily
WHERE period IS NOT NULL
GROUP BY 1,2
ORDER BY 1, 2 DESC;


SELECT
  DATE_TRUNC(install_date, WEEK) AS install_week,
  COUNT(*) AS installs,
  ROUND(100*COUNTIF(country_tier=1)/COUNT(*),1) AS pct_tier1,
  ROUND(100*COUNTIF(country_tier=4)/COUNT(*),1) AS pct_tier4,
  ROUND(100*COUNTIF(acquisition_channel='paid_video')/COUNT(*),1) AS pct_paid_video
FROM `db.player_profile`
WHERE install_date BETWEEN '2026-01-01' AND '2026-04-30'
GROUP BY 1
ORDER BY 1;

SELECT
  acquisition_channel,
  ROUND(100*COUNTIF(country_tier=1)/COUNT(*),1) AS pct_t1,
  ROUND(100*COUNTIF(country_tier=2)/COUNT(*),1) AS pct_t2,
  ROUND(100*COUNTIF(country_tier=3)/COUNT(*),1) AS pct_t3,
  ROUND(100*COUNTIF(country_tier=4)/COUNT(*),1) AS pct_t4
FROM `db.player_profile`
GROUP BY 1;

WITH pd AS (
  SELECT pd.device_id,
         PARSE_DATE('%Y%m%d', CAST(pd.activity_date AS STRING)) AS activity_dt,
         pp.country_tier
  FROM `db.player_day` pd
  JOIN `db.player_profile` pp USING(device_id)
),
dau AS (
  SELECT activity_dt, country_tier, COUNT(DISTINCT device_id) AS dau
  FROM pd
  GROUP BY 1, 2
),
pur AS (
  SELECT DATE(pu.event_ts) AS activity_dt, pp.country_tier, pu.usd_amount
  FROM `db.purchase` pu
  JOIN `db.player_profile` pp USING(device_id)
),
rev AS (
  SELECT activity_dt, country_tier, SUM(usd_amount) AS revenue
  FROM pur
  GROUP BY 1, 2
),
daily AS (
  SELECT d.activity_dt, d.country_tier, d.dau, COALESCE(r.revenue, 0) AS revenue,
    CASE WHEN d.activity_dt BETWEEN '2026-01-01' AND '2026-01-30' THEN 'first_30'
         WHEN d.activity_dt BETWEEN '2026-04-01' AND '2026-04-30' THEN 'last_30' END AS period
  FROM dau d
  LEFT JOIN rev r USING (activity_dt, country_tier)
),

tier_agg AS (
  SELECT country_tier, period, SUM(revenue) AS rev, SUM(dau) AS days
  FROM daily
  WHERE period IS NOT NULL
  GROUP BY 1,2
),
totals AS (
  SELECT period, SUM(days) AS total_days FROM tier_agg GROUP BY 1
)
SELECT t.country_tier, t.period,
       t.rev/t.days AS rate,
       t.days/tot.total_days AS weight
FROM tier_agg t JOIN totals tot USING(period)
ORDER BY period DESC, country_tier;