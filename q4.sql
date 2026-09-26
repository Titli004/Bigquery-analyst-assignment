# Q4 
-- Predicting which players are about to churn

CREATE OR REPLACE TABLE `db.churn_panel` AS
WITH snaps AS (
  SELECT snapshot_date
  FROM UNNEST(GENERATE_DATE_ARRAY('2026-01-15','2026-04-16', INTERVAL 7 DAY)) AS snapshot_date
),
pd_dates AS (
  SELECT device_id, PARSE_DATE('%Y%m%d', CAST(activity_date AS STRING)) AS act_date,
         session_count, playtime_minutes, player_level
  FROM `db.player_day`
),
active AS (
  SELECT s.snapshot_date, pd.device_id
  FROM snaps s
  JOIN pd_dates pd ON pd.act_date = s.snapshot_date
),
base AS (
  SELECT a.snapshot_date, a.device_id, pp.platform, pp.country_tier, pp.acquisition_channel,
         DATE_DIFF(a.snapshot_date, pp.install_date, DAY) AS tenure_days
  FROM active a
  JOIN `db.player_profile` pp USING(device_id)
  WHERE DATE_DIFF(a.snapshot_date, pp.install_date, DAY) >= 14
),
engagement AS (
  SELECT b.snapshot_date, b.device_id,
         COUNT(DISTINCT pd.act_date) AS active_days_last14
  FROM base b
  JOIN pd_dates pd ON pd.device_id = b.device_id
   AND pd.act_date BETWEEN DATE_SUB(b.snapshot_date, INTERVAL 13 DAY) AND b.snapshot_date
  GROUP BY 1,2
),
revenue AS (
  SELECT b.snapshot_date, b.device_id,
         COALESCE(SUM(IF(DATE(pu.event_ts) <= b.snapshot_date, pu.usd_amount, 0)), 0) AS lifetime_revenue,
         MAX(IF(DATE(pu.event_ts) <= b.snapshot_date, DATE(pu.event_ts), NULL)) AS last_purchase_date
  FROM base b
  LEFT JOIN `db.purchase` pu ON pu.device_id = b.device_id
  GROUP BY 1,2
),
ads AS (
  SELECT b.snapshot_date, b.device_id, COUNT(*) AS ad_views_last14
  FROM base b
  JOIN `db.ad_view` av ON av.device_id = b.device_id AND av.status = 'completed'
   AND DATE(av.event_ts) BETWEEN DATE_SUB(b.snapshot_date, INTERVAL 13 DAY) AND b.snapshot_date
  GROUP BY 1,2
),
label AS (
  SELECT b.snapshot_date, b.device_id,
         COUNTIF(pd.act_date BETWEEN DATE_ADD(b.snapshot_date, INTERVAL 1 DAY)
                                  AND DATE_ADD(b.snapshot_date, INTERVAL 14 DAY)) = 0 AS churn_14d
  FROM base b
  LEFT JOIN pd_dates pd ON pd.device_id = b.device_id
  GROUP BY 1,2
)
SELECT b.snapshot_date, b.device_id, b.platform, b.country_tier, b.acquisition_channel, b.tenure_days,
       COALESCE(e.active_days_last14,0) AS active_days_last14,
       r.lifetime_revenue, r.lifetime_revenue > 0 AS is_payer, r.last_purchase_date,
       COALESCE(ad.ad_views_last14,0) AS ad_views_last14,
       l.churn_14d
FROM base b
LEFT JOIN engagement e USING(snapshot_date, device_id)
LEFT JOIN revenue r USING(snapshot_date, device_id)
LEFT JOIN ads ad USING(snapshot_date, device_id)
JOIN label l USING(snapshot_date, device_id);

CREATE OR REPLACE MODEL `db.churn_model`
OPTIONS(model_type='logistic_reg', input_label_cols=['churn_14d']) AS
SELECT tenure_days, active_days_last14, lifetime_revenue, is_payer, ad_views_last14,
       platform, country_tier, acquisition_channel, churn_14d
FROM `db.churn_panel`
WHERE snapshot_date <= '2026-03-12';   -- train

SELECT *
FROM ML.EVALUATE(MODEL `db.churn_model`,
  (SELECT tenure_days, active_days_last14, lifetime_revenue, is_payer, ad_views_last14,
          platform, country_tier, acquisition_channel, churn_14d
   FROM `db.churn_panel`
   WHERE snapshot_date > '2026-03-12'));  -- test
