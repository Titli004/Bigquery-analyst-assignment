# Q1(c) Time To First Purchase
WITH player_conversion AS (
  SELECT
    device_id,
    install_date,
    first_purchase_date,
    DATE_DIFF(first_purchase_date, install_date, DAY) AS days_to_purchase,
    CASE
      WHEN first_purchase_date IS NOT NULL THEN 1
      ELSE 0
    END AS ever_paid
  FROM `db.player_profile`
)

SELECT *
FROM player_conversion;
