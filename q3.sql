# Q3
-- Is one cquisition better than the other ?
CREATE OR REPLACE TABLE `db.cohort_metrics` AS
WITH cohort AS (
  SELECT device_id, acquisition_channel, country_tier, install_date
  FROM `db.player_profile`
  WHERE install_date BETWEEN '2026-01-01' AND '2026-03-31'
),
d7 AS (
  SELECT c.device_id,
         EXISTS (
           SELECT 1 FROM `db.player_day` pd
           WHERE pd.device_id = c.device_id
             AND PARSE_DATE('%Y%m%d', CAST(pd.activity_date AS STRING)) = DATE_ADD(c.install_date, INTERVAL 7 DAY)
         ) AS d7_retained
  FROM cohort c
),
rev AS (
  SELECT c.device_id,
         COALESCE(SUM(IF(DATE(pu.event_ts) >= c.install_date
                          AND DATE(pu.event_ts) < DATE_ADD(c.install_date, INTERVAL 30 DAY),
                          pu.usd_amount, 0)), 0) AS rev_30d
  FROM cohort c
  LEFT JOIN `db.purchase` pu ON pu.device_id = c.device_id
  GROUP BY c.device_id
)
SELECT c.device_id, c.acquisition_channel, c.country_tier,
       d7.d7_retained, r.rev_30d, r.rev_30d > 0 AS paid_30d
FROM cohort c
JOIN d7 USING(device_id)
JOIN rev r USING(device_id);

SELECT acquisition_channel,
  COUNT(*) AS n,
  ROUND(AVG(IF(d7_retained,1,0)),4) AS d7_rate,
  ROUND(AVG(IF(paid_30d,1,0)),4) AS payer_rate,
  ROUND(AVG(rev_30d),4) AS arpu_30
FROM `db.cohort_metrics`
GROUP BY 1;

SELECT country_tier, acquisition_channel,
  COUNT(*) AS n,
  ROUND(AVG(IF(d7_retained,1,0)),4) AS d7_rate,
  ROUND(AVG(IF(paid_30d,1,0)),4) AS payer_rate,
  ROUND(AVG(rev_30d),4) AS arpu_30
FROM `db.cohort_metrics`
GROUP BY 1, 2
ORDER BY 1, 2;

CREATE OR REPLACE MODEL `db.d7_retention_model`
OPTIONS(model_type='logistic_reg', input_label_cols=['d7_retained']) AS
SELECT d7_retained, acquisition_channel, country_tier
FROM `db.cohort_metrics`;

SELECT * FROM ML.WEIGHTS(MODEL `db.d7_retention_model`);