
-- ============================================================
-- PROJECT: BRAZILIAN E-COMMERCE BUSINESS ANALYSIS
-- TOOL: GOOGLE BIGQUERY
-- FILE: Ecommerce_Analysis.sql
-- ============================================================


-- ============================================================
-- SECTION 1: EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================

-- QUERY 1: Check the data types of all columns in customers

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


-- QUERY 3: Count the distinct cities and states of customers
-- who placed orders

SELECT
    COUNT(DISTINCT c.customer_city) AS no_of_cities,
    COUNT(DISTINCT c.customer_state) AS no_of_states
FROM `sql.orders` AS o
JOIN `sql.customers` AS c
    USING (customer_id);



-- ============================================================
-- SECTION 2: IN-DEPTH EXPLORATION
-- ============================================================

-- QUERY 4: Check the yearly growth in the number of orders

SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
    COUNT(*) AS total_orders
FROM `sql.orders`
GROUP BY order_year
ORDER BY order_year;


-- QUERY 5: Identify monthly order trends and seasonality

SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
    COUNT(*) AS total_orders
FROM `sql.orders`
GROUP BY order_year, order_month
ORDER BY order_year, order_month;


-- QUERY 6: Identify the time of day when customers place orders
-- Dawn:      00:00–06:00
-- Morning:   07:00–12:00
-- Afternoon: 13:00–18:00
-- Night:     19:00–23:00

WITH days AS (
    SELECT
        EXTRACT(HOUR FROM order_purchase_timestamp) AS hour_of_day
    FROM `sql.orders`
)

SELECT
    CASE
        WHEN hour_of_day BETWEEN 0 AND 6 THEN 'Dawn'
        WHEN hour_of_day BETWEEN 7 AND 12 THEN 'Morning'
        WHEN hour_of_day BETWEEN 13 AND 18 THEN 'Afternoon'
        ELSE 'Night'
    END AS time_of_day,
    COUNT(*) AS total_orders
FROM days
GROUP BY time_of_day
ORDER BY total_orders DESC;



-- ============================================================
-- SECTION 3: EVOLUTION OF E-COMMERCE ORDERS IN BRAZIL
-- ============================================================

-- QUERY 7: Calculate month-on-month orders in each state

SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS order_month,
    c.customer_state,
    COUNT(*) AS total_orders
FROM `sql.orders` AS o
JOIN `sql.customers` AS c
    ON o.customer_id = c.customer_id
GROUP BY
    order_year,
    order_month,
    c.customer_state
ORDER BY
    c.customer_state,
    order_year,
    order_month;


-- QUERY 8: Find the customer distribution across states

SELECT
    customer_state,
    COUNT(DISTINCT customer_id) AS total_customers
FROM `sql.customers`
GROUP BY customer_state
ORDER BY total_customers DESC;



-- ============================================================
-- SECTION 4: IMPACT ON ECONOMY
-- Analyze order value and freight movement
-- ============================================================

-- QUERY 9: Calculate the percentage increase in payment value
-- from January–August 2017 to January–August 2018

WITH df AS (
    SELECT
        EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
        EXTRACT(MONTH FROM o.order_purchase_timestamp) AS order_month,
        p.payment_value
    FROM `sql.orders` AS o
    JOIN `sql.payments` AS p
        ON o.order_id = p.order_id
    WHERE
        EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
        AND EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
),

t17 AS (
    SELECT
        ROUND(SUM(payment_value), 2) AS total_2017
    FROM df
    WHERE order_year = 2017
),

t18 AS (
    SELECT
        ROUND(SUM(payment_value), 2) AS total_2018
    FROM df
    WHERE order_year = 2018
)

SELECT
    t17.total_2017,
    t18.total_2018,
    ROUND(
        100.0 * (t18.total_2018 - t17.total_2017)
        / t17.total_2017,
        2
    ) AS percent_increase
FROM t17, t18;


-- QUERY 10: Calculate the total and average order value for each state

SELECT
    c.customer_state,
    ROUND(SUM(oi.price), 2) AS total_order_value,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM `sql.order_items` AS oi
JOIN `sql.orders` AS o
    ON oi.order_id = o.order_id
JOIN `sql.customers` AS c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_order_value DESC;


-- QUERY 11: Calculate the total and average freight value for each state

SELECT
    c.customer_state,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(
        SUM(oi.freight_value) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_freight_value
FROM `sql.order_items` AS oi
JOIN `sql.orders` AS o
    ON oi.order_id = o.order_id
JOIN `sql.customers` AS c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_freight_value DESC;



-- ============================================================
-- SECTION 5: SALES, FREIGHT AND DELIVERY TIME ANALYSIS
-- ============================================================

-- QUERY 12: Calculate delivery time and difference between
-- actual and estimated delivery dates for each delivered order

SELECT
    order_id,
    order_purchase_timestamp,
    order_estimated_delivery_date,
    order_delivered_customer_date,

    DATE_DIFF(
        DATE(order_delivered_customer_date),
        DATE(order_purchase_timestamp),
        DAY
    ) AS time_to_deliver,

    DATE_DIFF(
        DATE(order_delivered_customer_date),
        DATE(order_estimated_delivery_date),
        DAY
    ) AS diff_estimated_delivery

FROM `scalerdsml-458814.sql.orders`
WHERE order_delivered_customer_date IS NOT NULL
ORDER BY diff_estimated_delivery;


-- QUERY 13: Find the top 5 states with the highest and lowest
-- average freight value

WITH state_avg AS (
    SELECT
        c.customer_state,
        ROUND(AVG(oi.freight_value), 2) AS avg_freight
    FROM `scalerdsml-458814.sql.customers` AS c
    JOIN `scalerdsml-458814.sql.orders` AS o
        ON c.customer_id = o.customer_id
    JOIN `scalerdsml-458814.sql.order_items` AS oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_state
),

ranked AS (
    SELECT
        customer_state,
        avg_freight,
        DENSE_RANK() OVER (ORDER BY avg_freight DESC) AS high_rank,
        DENSE_RANK() OVER (ORDER BY avg_freight ASC) AS low_rank
    FROM state_avg
)

SELECT
    customer_state,
    avg_freight,
    'High' AS rank_label
FROM ranked
WHERE high_rank <= 5

UNION ALL

SELECT
    customer_state,
    avg_freight,
    'Low' AS rank_label
FROM ranked
WHERE low_rank <= 5

ORDER BY rank_label;


-- QUERY 14: Find the top 5 states with the highest and lowest
-- average delivery time

WITH state_avg AS (
    SELECT
        c.customer_state,
        ROUND(
            AVG(
                DATE_DIFF(
                    DATE(o.order_delivered_customer_date),
                    DATE(o.order_purchase_timestamp),
                    DAY
                )
            ),
            2
        ) AS avg_delivery_time
    FROM `scalerdsml-458814.sql.customers` AS c
    JOIN `scalerdsml-458814.sql.orders` AS o
        ON c.customer_id = o.customer_id
    JOIN `scalerdsml-458814.sql.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
),

ranked AS (
    SELECT
        customer_state,
        avg_delivery_time,
        DENSE_RANK() OVER (
            ORDER BY avg_delivery_time DESC
        ) AS high_rank,
        DENSE_RANK() OVER (
            ORDER BY avg_delivery_time ASC
        ) AS low_rank
    FROM state_avg
)

SELECT
    customer_state,
    avg_delivery_time,
    'High' AS rank_label
FROM ranked
WHERE high_rank <= 5

UNION ALL

SELECT
    customer_state,
    avg_delivery_time,
    'Low' AS rank_label
FROM ranked
WHERE low_rank <= 5

ORDER BY rank_label;


-- QUERY 15: Find the top 5 states where orders are delivered
-- earliest compared with the estimated delivery date

WITH early_delivery AS (
    SELECT
        c.customer_state,
        ROUND(
            AVG(
                DATE_DIFF(
                    DATE(o.order_estimated_delivery_date),
                    DATE(o.order_delivered_customer_date),
                    DAY
                )
            ),
            2
        ) AS avg_days_early
    FROM `scalerdsml-458814.sql.orders` AS o
    JOIN `scalerdsml-458814.sql.customers` AS c
        ON o.customer_id = c.customer_id
    WHERE
        o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY c.customer_state
),

ranked_states AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY avg_days_early DESC
        ) AS rnk
    FROM early_delivery
    WHERE avg_days_early > 0
)

SELECT
    customer_state,
    avg_days_early
FROM ranked_states
WHERE rnk <= 5;



-- ============================================================
-- SECTION 6: PAYMENT ANALYSIS
-- ============================================================

-- QUERY 16: Find month-on-month orders by payment type

SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS order_count
FROM `scalerdsml-458814.sql.orders` AS o
JOIN `scalerdsml-458814.sql.payments` AS p
    ON o.order_id = p.order_id
GROUP BY
    year,
    month,
    p.payment_type
ORDER BY
    year,
    month,
    payment_type;


-- QUERY 17: Find the number of orders by payment installments

SELECT
    payment_installments,
    COUNT(DISTINCT order_id) AS order_count
FROM `scalerdsml-458814.sql.payments`
WHERE payment_installments > 0
GROUP BY payment_installments
ORDER BY payment_installments;


-- ============================================================
-- END OF PROJECT SQL QUERIES
-- ============================================================
