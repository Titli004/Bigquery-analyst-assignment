#q1(c) Repeat Purchase gap

WITH ordered_purchases AS (
  SELECT
    device_id,
    event_ts AS purchase_timestamp,
    LAG(event_ts) OVER (
      PARTITION BY device_id
      ORDER BY event_ts ASC
    ) AS prev_purchase_timestamp
  FROM `db.purchase`
),

purchase_gaps AS (
  SELECT
    device_id,
    prev_purchase_timestamp,
    TIMESTAMP_DIFF(
      purchase_timestamp,
      prev_purchase_timestamp,
      HOUR
    ) AS hours_to_next_purchase
  FROM ordered_purchases
  WHERE prev_purchase_timestamp IS NOT NULL
)

-- Summary statistics or raw distribution of the purchase gap
SELECT
  ROUND(AVG(hours_to_next_purchase), 2) AS avg_hours_between_purchases,
  APPROX_QUANTILES(
    hours_to_next_purchase, 2
  )[OFFSET(1)] AS median_hours_between_purchases
FROM purchase_gaps;
