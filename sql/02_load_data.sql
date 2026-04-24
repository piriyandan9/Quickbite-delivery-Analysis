-- ============================================================
-- Load CSV data into warehouse tables
-- ============================================================
-- Order matters: dimensions first, then fact (FK constraints)

-- Load dimensions
INSERT INTO dim_courier
SELECT * FROM read_csv_auto('data/processed/dim_courier.csv', header=TRUE);

INSERT INTO dim_restaurant
SELECT * FROM read_csv_auto('data/processed/dim_restaurant.csv', header=TRUE);

INSERT INTO dim_date
SELECT * FROM read_csv_auto('data/processed/dim_date.csv', header=TRUE);

INSERT INTO dim_location
SELECT * FROM read_csv_auto('data/processed/dim_location.csv', header=TRUE);

INSERT INTO dim_conditions
SELECT * FROM read_csv_auto('data/processed/dim_conditions.csv', header=TRUE);

-- Load fact last (depends on all dims existing)
INSERT INTO fact_orders
SELECT * FROM read_csv_auto('data/processed/fact_orders.csv', header=TRUE);