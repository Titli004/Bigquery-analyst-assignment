# Q1
# a.) daily health -- daily, platform split
-- Daily Active Player


WITH
  player_data AS (
    SELECT
      PARSE_DATE('%Y%m%d', CAST(activity_date AS STRING)) AS date, device_id
    FROM `db.player_day`
  ),
  platform AS (
    SELECT device_id, platform
    FROM `db.player_profile`
  ),
  revenue AS (
    SELECT device_id, date(event_ts) AS date, sum(usd_amount) AS revenue
    FROM `db.purchase`
    GROUP BY 1, 2
  )
SELECT
  d.date,
  platform,
  COUNT(DISTINCT d.device_id) AS users,
  sum(revenue) AS revenue,
  COUNT(DISTINCT r.device_id) AS payers
FROM player_data AS d
LEFT JOIN platform AS p
  ON d.device_id = p.device_id
LEFT JOIN revenue AS r
  ON d.device_id = r.device_id AND d.date = r.date
GROUP BY 1, 2
ORDER BY 1, 2

