-- ============================================================
-- Verification queries — confirm loads match Python counts
-- ============================================================

SELECT 'fact_orders' AS table_name, COUNT(*) AS row_count FROM fact_orders
UNION ALL
SELECT 'dim_courier', COUNT(*) FROM dim_courier
UNION ALL
SELECT 'dim_restaurant', COUNT(*) FROM dim_restaurant
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL
SELECT 'dim_conditions', COUNT(*) FROM dim_conditions;