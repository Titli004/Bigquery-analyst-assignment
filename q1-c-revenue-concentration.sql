# Q1 (c)
--- Revenue Concentration
WITH daily_player_spend AS (
    SELECT
        DATE(p.event_ts) AS activity_date,
        p.device_id,
        SUM(p.usd_amount) AS daily_spend
    FROM `db.purchase` p
    GROUP BY
        activity_date,
        p.device_id
),

ranked_daily_payers AS (
    SELECT
        activity_date,
        device_id,
        daily_spend,

        PERCENT_RANK() OVER (
            PARTITION BY activity_date
            ORDER BY daily_spend DESC
        ) AS spend_pct_rank,

        SUM(daily_spend) OVER (
            PARTITION BY activity_date
        ) AS total_daily_revenue

    FROM daily_player_spend
)

SELECT
    activity_date,

    SUM(
        CASE
            WHEN spend_pct_rank <= 0.01
            THEN daily_spend
            ELSE 0
        END
    ) / MAX(total_daily_revenue) AS top_1_pct_share,

    SUM(
        CASE
            WHEN spend_pct_rank <= 0.10
            THEN daily_spend
            ELSE 0
        END
    ) / MAX(total_daily_revenue) AS top_10_pct_share,

    SUM(
        CASE
            WHEN spend_pct_rank <= 0.50
            THEN daily_spend
            ELSE 0
        END
    ) / MAX(total_daily_revenue) AS top_50_pct_share,

    MAX(total_daily_revenue) AS total_daily_revenue

FROM ranked_daily_payers

GROUP BY
    activity_date

ORDER BY
    activity_date;
