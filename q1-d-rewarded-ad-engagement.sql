# Q1 (D)
-- Rewarded Ad Engagement
WITH filtered_player_days AS (
    SELECT
        device_id,
        DATE(event_ts) AS activity_date,
        MAX(ad_daily_cap) AS ad_daily_cap,
        MAX(ad_daily_count) AS max_daily_count
    FROM `db.ad_view`
    GROUP BY device_id, DATE(event_ts)
    HAVING MAX(ad_daily_count) > 0
)

SELECT
    activity_date,
    ad_daily_cap AS cap_value,
    COUNT(DISTINCT device_id) AS total_ad_watching_player_days,
    SUM(
        CASE
            WHEN max_daily_count >= ad_daily_cap THEN 1
            ELSE 0
        END
    ) AS player_days_hitting_cap
FROM filtered_player_days
GROUP BY activity_date, ad_daily_cap
ORDER BY activity_date, ad_daily_cap;
