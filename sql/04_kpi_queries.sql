-- ============================================================
-- QuickBite Analytics — KPI Queries
-- ============================================================
-- 6 analytical queries answering the COO's business questions.
-- Each query is independently runnable.
-- Engine: DuckDB
-- Author: Piriyandan
-- ============================================================


-- ============================================================
-- Q1: Weekly SLA Performance Trend
-- ============================================================
-- Pattern: CTE + DATE manipulation + CASE WHEN aggregation
-- Business question: How is our 30-min SLA performance trending week-over-week?

WITH weekly_stats AS (
    SELECT 
        DATE_TRUNC('week', d.order_date) AS week_start,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END) AS on_time_orders,
        ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min
    FROM fact_orders f
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY week_start
)
SELECT 
    week_start,
    total_orders,
    on_time_orders,
    avg_delivery_min,
    ROUND(100.0 * on_time_orders / total_orders, 1) AS sla_pct
FROM weekly_stats
ORDER BY week_start;


-- ============================================================
-- Q2: Operational Bottleneck Analysis
-- ============================================================
-- Pattern: Multi-table JOIN + UNION ALL across factors
-- Business question: Which factor hurts delivery time most?

SELECT 
    'Traffic: ' || c.traffic AS factor,
    COUNT(*) AS order_count,
    ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min,
    ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1) AS sla_pct
FROM fact_orders f
JOIN dim_conditions c ON f.condition_id = c.condition_id
GROUP BY c.traffic

UNION ALL

SELECT 
    'Weather: ' || c.weather AS factor,
    COUNT(*),
    ROUND(AVG(f.delivery_minutes), 1),
    ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1)
FROM fact_orders f
JOIN dim_conditions c ON f.condition_id = c.condition_id
GROUP BY c.weather

UNION ALL

SELECT 
    CASE WHEN f.is_peak_hour THEN 'Peak Hour: Yes' ELSE 'Peak Hour: No' END,
    COUNT(*),
    ROUND(AVG(f.delivery_minutes), 1),
    ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1)
FROM fact_orders f
GROUP BY f.is_peak_hour

UNION ALL

SELECT 
    'Vehicle: ' || f.vehicle_type,
    COUNT(*),
    ROUND(AVG(f.delivery_minutes), 1),
    ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1)
FROM fact_orders f
GROUP BY f.vehicle_type

ORDER BY avg_delivery_min DESC;


-- ============================================================
-- Q3: Courier Performance Ranking (Top and Bottom 10)
-- ============================================================
-- Pattern: Two CTEs + Window functions (RANK) + HAVING filter
-- Business question: Best and worst couriers by SLA performance

WITH courier_stats AS (
    SELECT 
        f.courier_id,
        c.courier_age,
        c.courier_rating,
        c.vehicle_condition,
        COUNT(*) AS total_orders,
        ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min,
        ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1) AS on_time_pct
    FROM fact_orders f
    JOIN dim_courier c ON f.courier_id = c.courier_id
    GROUP BY f.courier_id, c.courier_age, c.courier_rating, c.vehicle_condition
    HAVING COUNT(*) >= 20
),
ranked AS (
    SELECT 
        *,
        RANK() OVER (ORDER BY on_time_pct DESC, avg_delivery_min ASC) AS top_rank,
        RANK() OVER (ORDER BY on_time_pct ASC, avg_delivery_min DESC) AS bottom_rank
    FROM courier_stats
)
SELECT 
    courier_id, 
    courier_age, 
    courier_rating, 
    total_orders,
    avg_delivery_min,
    on_time_pct,
    'TOP' AS performance_group
FROM ranked WHERE top_rank <= 10

UNION ALL

SELECT 
    courier_id, 
    courier_age, 
    courier_rating, 
    total_orders,
    avg_delivery_min,
    on_time_pct,
    'BOTTOM' AS performance_group
FROM ranked WHERE bottom_rank <= 10

ORDER BY performance_group, on_time_pct DESC;


-- ============================================================
-- Q4: Geographic Hotspot Analysis
-- ============================================================
-- Pattern: CASE WHEN bucketing + multi-dimensional aggregation
-- Business question: Where are our delivery hotspots?

SELECT 
    l.city_type,
    CASE 
        WHEN f.distance_km < 5 THEN '0-5 km (short)'
        WHEN f.distance_km < 10 THEN '5-10 km (medium)'
        WHEN f.distance_km < 20 THEN '10-20 km (long)'
        ELSE '20+ km (very long)'
    END AS distance_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min,
    ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1) AS sla_pct
FROM fact_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.city_type, distance_bucket
ORDER BY l.city_type, avg_delivery_min DESC;

-- ============================================================
-- Q5: Restaurant Prep Time Analysis (slowest kitchens)
-- ============================================================
-- Pattern: Time arithmetic + CTE + HAVING filter
-- Business question: Are slow deliveries the courier's fault or the restaurant's?
-- Note: DuckDB doesn't allow direct TIME - TIME subtraction.
-- Solution: convert each TIME to total seconds, then subtract.

WITH restaurant_perf AS (
    SELECT 
        f.restaurant_id,
        r.restaurant_lat,
        r.restaurant_lng,
        COUNT(*) AS total_orders,
        ROUND(AVG(
            (EXTRACT(HOUR FROM f.time_picked) * 3600 + 
             EXTRACT(MINUTE FROM f.time_picked) * 60 + 
             EXTRACT(SECOND FROM f.time_picked))
            -
            (EXTRACT(HOUR FROM f.time_ordered) * 3600 + 
             EXTRACT(MINUTE FROM f.time_ordered) * 60 + 
             EXTRACT(SECOND FROM f.time_ordered))
        ) / 60.0, 1) AS avg_prep_min,
        ROUND(AVG(f.delivery_minutes), 1) AS avg_total_delivery_min,
        ROUND(100.0 * SUM(f.is_on_time) / COUNT(*), 1) AS sla_pct
    FROM fact_orders f
    JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
    GROUP BY f.restaurant_id, r.restaurant_lat, r.restaurant_lng
    HAVING COUNT(*) >= 30
)
SELECT 
    restaurant_id,
    restaurant_lat,
    restaurant_lng,
    total_orders,
    avg_prep_min,
    avg_total_delivery_min,
    sla_pct
FROM restaurant_perf
ORDER BY avg_prep_min DESC
LIMIT 15;


-- ============================================================
-- Q6: Festival Day Impact Analysis
-- ============================================================
-- Pattern: CTE + LAG window function for row-over-row comparison
-- Business question: Should festival days have adjusted SLA targets?

WITH festival_comparison AS (
    SELECT 
        is_festival,
        COUNT(*) AS order_count,
        ROUND(AVG(delivery_minutes), 1) AS avg_delivery_min,
        ROUND(AVG(distance_km), 1) AS avg_distance_km,
        ROUND(100.0 * SUM(is_on_time) / COUNT(*), 1) AS sla_pct
    FROM fact_orders
    GROUP BY is_festival
)
SELECT 
    is_festival,
    order_count,
    avg_delivery_min,
    avg_distance_km,
    sla_pct,
    ROUND(
        avg_delivery_min - LAG(avg_delivery_min) OVER (ORDER BY is_festival), 1
    ) AS delivery_min_diff_vs_no_festival
FROM festival_comparison
ORDER BY is_festival;