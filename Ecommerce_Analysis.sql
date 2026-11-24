
-- =====================================================
-- PROJECT: Brazilian E-commerce Business Analysis
-- TOOL: Google BigQuery
-- SECTION 1: EXPLORATORY DATA ANALYSIS (EDA)
-- =====================================================


-- QUERY 1: Check the data types of all columns
-- in the customers table

SELECT
    column_name,
    data_type
FROM `scalerdsml-458814.sql.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'customers';


-- QUERY 2: Find the earliest and latest order dates

SELECT
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order
FROM `sql.orders`;


-- QUERY 3: Count the distinct cities and states
-- of customers who placed orders

SELECT
    COUNT(DISTINCT c.customer_city) AS No_of_cities,
    COUNT(DISTINCT c.customer_state) AS No_of_states
FROM sql.orders o
JOIN sql.customers c
    USING (customer_id);

