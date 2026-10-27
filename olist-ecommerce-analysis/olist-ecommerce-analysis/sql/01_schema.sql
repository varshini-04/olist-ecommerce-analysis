-- =====================================================================
-- Olist E-Commerce Analysis: database schema (PostgreSQL)
-- =====================================================================
-- How to use (from the project root, in psql):
--   CREATE DATABASE olist
--   \c olist
--   \i sql/01_schema.sql
--
-- No PostgreSQL installed? Run  python sql/run_queries.py  instead.
-- It loads the same schema into DuckDB (an in-process database that
-- understands the same SQL) and runs every query in 02_business_questions.sql.
-- =====================================================================

DROP VIEW IF EXISTS v_delivered_orders, v_products, v_reviews CASCADE;
DROP TABLE IF EXISTS reviews, payments, order_items, orders, products, sellers, customers, category_translation CASCADE;

-- ---------------------------------------------------------------------
-- 1. Tables (parents first, so foreign keys can be enforced)
-- ---------------------------------------------------------------------

CREATE TABLE customers (
    customer_id              VARCHAR(32) PRIMARY KEY,   -- new id for EVERY order
    customer_unique_id       VARCHAR(32) NOT NULL,      -- the real person
    customer_zip_code_prefix VARCHAR(5),                -- text: keeps leading zeros
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

CREATE TABLE category_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

CREATE TABLE products (
    product_id                 VARCHAR(32) PRIMARY KEY,
    product_category_name      VARCHAR(100),
    product_name_lenght        INT,          -- spelling kept from the source file
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);

CREATE TABLE orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL REFERENCES customers (customer_id),
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      TIMESTAMP   NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id            VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    order_item_id       INT         NOT NULL,
    product_id          VARCHAR(32) NOT NULL REFERENCES products (product_id),
    seller_id           VARCHAR(32) NOT NULL REFERENCES sellers (seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10, 2),
    freight_value       NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE payments (
    order_id             VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    payment_sequential   INT         NOT NULL,
    payment_type         VARCHAR(20),
    payment_installments INT,
    payment_value        NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE reviews (
    review_id               VARCHAR(32) NOT NULL,   -- NOT unique in the source data
    order_id                VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    review_score            INT CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. Load the CSV files (psql client-side copy)
-- ---------------------------------------------------------------------
\copy customers            FROM 'data/raw/olist_customers_dataset.csv'          WITH (FORMAT csv, HEADER true)
\copy sellers              FROM 'data/raw/olist_sellers_dataset.csv'            WITH (FORMAT csv, HEADER true)
\copy category_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)
\copy products             FROM 'data/raw/olist_products_dataset.csv'           WITH (FORMAT csv, HEADER true)
\copy orders               FROM 'data/raw/olist_orders_dataset.csv'             WITH (FORMAT csv, HEADER true)
\copy order_items          FROM 'data/raw/olist_order_items_dataset.csv'        WITH (FORMAT csv, HEADER true)
\copy payments             FROM 'data/raw/olist_order_payments_dataset.csv'     WITH (FORMAT csv, HEADER true)
\copy reviews              FROM 'data/raw/olist_order_reviews_dataset.csv'      WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------------
-- 3. Cleaning views (the same rules as notebook 01)
-- ---------------------------------------------------------------------

-- Some orders have several reviews: keep the most recently answered one
CREATE VIEW v_reviews AS
SELECT order_id, review_score, review_creation_date
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
    FROM reviews r
) ranked
WHERE rn = 1;

-- English category names, two missing translations added, NULL categories labelled 'unknown'
CREATE VIEW v_products AS
SELECT p.product_id,
       COALESCE(
           t.product_category_name_english,
           CASE p.product_category_name
               WHEN 'pc_gamer' THEN 'pc_gamer'
               WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_food_processors'
           END,
           'unknown') AS category,
       p.product_weight_g
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name;

-- One row per delivered order with value, delivery and review metrics
--   order_value  = item price + freight
--   is_late      = delivered on a later calendar day than the estimate
CREATE VIEW v_delivered_orders AS
WITH item_totals AS (
    SELECT order_id,
           COUNT(*)                   AS item_count,
           SUM(price)                 AS product_value,
           SUM(freight_value)         AS freight_value,
           SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id
)
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_purchase_timestamp,
       CAST(DATE_TRUNC('month', o.order_purchase_timestamp) AS DATE) AS purchase_month,
       it.item_count,
       it.product_value,
       it.freight_value,
       it.order_value,
       EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 AS delivery_days,
       CAST(o.order_delivered_customer_date AS DATE) - CAST(o.order_estimated_delivery_date AS DATE) AS delay_days,
       CASE
           WHEN o.order_delivered_customer_date IS NULL THEN NULL
           WHEN CAST(o.order_delivered_customer_date AS DATE) > CAST(o.order_estimated_delivery_date AS DATE) THEN 1
           ELSE 0
       END AS is_late,
       r.review_score
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN item_totals it ON it.order_id = o.order_id
LEFT JOIN v_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered';
