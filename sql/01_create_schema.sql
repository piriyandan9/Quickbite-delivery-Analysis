-- ============================================================
-- QuickBite Data Warehouse — Schema Definition
-- ============================================================
-- Star schema: 1 fact table + 5 dimension tables
-- Target engine: DuckDB

-- Drop existing tables (safe to rerun)
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_courier;
DROP TABLE IF EXISTS dim_restaurant;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_conditions;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================
-- Dimensions are loaded first because fact_orders references them

CREATE TABLE dim_courier (
    courier_id VARCHAR PRIMARY KEY,
    courier_age INTEGER,
    courier_rating DECIMAL(3,2),
    vehicle_condition INTEGER
);

CREATE TABLE dim_restaurant (
    restaurant_id INTEGER PRIMARY KEY,
    restaurant_key VARCHAR,
    restaurant_lat DECIMAL(10,6),
    restaurant_lng DECIMAL(10,6)
);

CREATE TABLE dim_date (
    date_id INTEGER PRIMARY KEY,
    order_date DATE,
    day_of_week VARCHAR(10),
    is_weekend BOOLEAN,
    month VARCHAR(15),
    year INTEGER
);

CREATE TABLE dim_location (
    location_id INTEGER PRIMARY KEY,
    city_type VARCHAR(20)
);

CREATE TABLE dim_conditions (
    condition_id INTEGER PRIMARY KEY,
    weather VARCHAR(20),
    traffic VARCHAR(20)
);

-- ============================================================
-- FACT TABLE
-- ============================================================
-- Foreign keys enforce that every fact row references valid dimensions

CREATE TABLE fact_orders (
    order_id VARCHAR PRIMARY KEY,
    courier_id VARCHAR,
    restaurant_id INTEGER,
    date_id INTEGER,
    location_id INTEGER,
    condition_id INTEGER,
    order_type VARCHAR(15),
    vehicle_type VARCHAR(20),
    multi_deliveries INTEGER,
    is_festival VARCHAR(3),
    delivery_minutes INTEGER,
    distance_km DECIMAL(6,2),
    is_on_time INTEGER,
    order_hour INTEGER,
    is_peak_hour BOOLEAN,
    time_ordered TIME,
    time_picked TIME,
    delivery_lat DECIMAL(10,6),  
    delivery_lng DECIMAL(10,6),
    FOREIGN KEY (courier_id) REFERENCES dim_courier(courier_id),
    FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    FOREIGN KEY (condition_id) REFERENCES dim_conditions(condition_id)
);