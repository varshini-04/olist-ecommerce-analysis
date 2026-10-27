-- =====================================================================
-- Olist E-Commerce Analysis: business questions in SQL
-- =====================================================================
-- Run 01_schema.sql first. Written for PostgreSQL; also runs unchanged
-- in DuckDB via  python sql/run_queries.py  (results: sql/query_results.md).
--
-- SQL skills shown: multi-table JOINs, CTEs, aggregate FILTER clauses,
-- CASE bucketing, and window functions (LAG, RANK, ROW_NUMBER, NTILE,
-- running SUM ... OVER).
-- =====================================================================


-- Q1. Headline KPIs: how big is the business?
-- Insight: 96,478 delivered orders from 93,358 customers, R$15.42M revenue, AOV R$159.83,
--          avg review 4.16, avg delivery 12.6 days, 6.8% delivered late.
SELECT COUNT(*)                                AS delivered_orders,
       COUNT(DISTINCT customer_unique_id)      AS customers,
       ROUND(SUM(order_value), 2)              AS revenue,
       ROUND(AVG(order_value), 2)              AS avg_order_value,
       ROUND(AVG(review_score), 2)             AS avg_review_score,
       ROUND(CAST(AVG(delivery_days) AS NUMERIC), 1) AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late), 1)          AS late_delivery_pct
FROM v_delivered_orders;


-- Q2. Monthly revenue and month-over-month growth (LAG window function)
-- Insight: strong growth through 2017 (Nov 2017 +53.6% on Black Friday), then a plateau
--          at roughly R$1.0-1.1M per month through 2018.
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)         AS orders,
           SUM(order_value) AS revenue
    FROM v_delivered_orders
    WHERE purchase_month BETWEEN DATE '2017-01-01' AND DATE '2018-08-01'
    GROUP BY purchase_month
)
SELECT purchase_month,
       orders,
       ROUND(revenue, 2)          AS revenue,
       ROUND(revenue / orders, 2) AS avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
                   / LAG(revenue) OVER (ORDER BY purchase_month), 1) AS mom_growth_pct
FROM monthly
ORDER BY purchase_month;


-- Q3. Year-over-year growth: January-August 2018 vs January-August 2017
-- Insight: R$3.47M -> R$8.45M, +143.4% year over year.
WITH ytd AS (
    SELECT SUM(order_value) FILTER (WHERE purchase_month BETWEEN DATE '2017-01-01' AND DATE '2017-08-01') AS revenue_2017,
           SUM(order_value) FILTER (WHERE purchase_month BETWEEN DATE '2018-01-01' AND DATE '2018-08-01') AS revenue_2018
    FROM v_delivered_orders
)
SELECT ROUND(revenue_2017, 2) AS jan_aug_2017,
       ROUND(revenue_2018, 2) AS jan_aug_2018,
       ROUND(100.0 * (revenue_2018 - revenue_2017) / revenue_2017, 1) AS yoy_growth_pct
FROM ytd;


-- Q4. The five busiest days
-- Insight: Black Friday (24 Nov 2017) had 1,147 orders, about 7x an average day (~160).
SELECT CAST(order_purchase_timestamp AS DATE) AS order_date,
       COUNT(*)                               AS orders,
       ROUND(SUM(order_value), 2)             AS revenue
FROM v_delivered_orders
GROUP BY CAST(order_purchase_timestamp AS DATE)
ORDER BY orders DESC
LIMIT 5;


-- Q5. Top 10 categories by revenue, with share and running (cumulative) share
-- Insight: 8 of 74 categories make up half of revenue; the top 10 make up 62.4%.
WITH category_revenue AS (
    SELECT p.category,
           COUNT(DISTINCT oi.order_id)        AS orders,
           SUM(oi.price + oi.freight_value)   AS revenue
    FROM order_items oi
    JOIN orders o     ON o.order_id = oi.order_id AND o.order_status = 'delivered'
    JOIN v_products p ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
       category,
       orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS revenue_share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                   / SUM(revenue) OVER (), 1) AS cumulative_share_pct
FROM category_revenue
ORDER BY revenue DESC
LIMIT 10;


-- Q6. Lowest-rated large categories (500+ delivered orders)
-- Insight: office_furniture is the clear outlier: 3.64 avg review and 20.6 days to deliver.
WITH order_category AS (
    SELECT DISTINCT oi.order_id, p.category
    FROM order_items oi
    JOIN v_products p ON p.product_id = oi.product_id
)
SELECT oc.category,
       COUNT(*)                                        AS orders,
       ROUND(AVG(d.review_score), 2)                   AS avg_review,
       ROUND(CAST(AVG(d.delivery_days) AS NUMERIC), 1) AS avg_delivery_days,
       ROUND(100.0 * AVG(d.is_late), 1)                AS late_pct
FROM order_category oc
JOIN v_delivered_orders d ON d.order_id = oc.order_id
GROUP BY oc.category
HAVING COUNT(*) >= 500
ORDER BY avg_review
LIMIT 5;


-- Q7. How does delivery delay affect review scores? (CASE bucketing)
-- Insight: on-time orders average 4.29; orders 4+ days late average about 2,
--          and 68-80% of them receive a 1-2 star review.
SELECT CASE
           WHEN delay_days <= 0  THEN '1. On time'
           WHEN delay_days <= 3  THEN '2. 1-3 days late'
           WHEN delay_days <= 7  THEN '3. 4-7 days late'
           WHEN delay_days <= 14 THEN '4. 8-14 days late'
           ELSE                       '5. 15+ days late'
       END                           AS delivery_status,
       COUNT(*)                      AS orders,
       ROUND(AVG(review_score), 2)   AS avg_review,
       ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1.0
                              WHEN review_score IS NOT NULL THEN 0.0 END), 1) AS pct_1_2_star_reviews
FROM v_delivered_orders
WHERE delay_days IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Q8. Share of all 1-2 star reviews that come from late orders
-- Insight: late orders are only 6.8% of deliveries but cause 32.5% of all 1-2 star reviews.
SELECT ROUND(100.0 * AVG(is_late), 1) AS pct_of_orders_late,
       ROUND(100.0 * AVG(is_late) FILTER (WHERE review_score <= 2), 1) AS pct_of_bad_reviews_from_late_orders
FROM v_delivered_orders
WHERE is_late IS NOT NULL;


-- Q9. Delivery performance by state, ranked by late-delivery rate
-- Insight: Northeast states (AL 21.4%, MA 17.4%) are late most often. RJ, the #2 market,
--          is late 12.1% of the time vs 4.5% for SP. AM/AP are slow but rarely late, and still score high.
SELECT RANK() OVER (ORDER BY AVG(is_late) DESC)          AS late_rank,
       customer_state,
       COUNT(*)                                          AS orders,
       ROUND(CAST(AVG(delivery_days) AS NUMERIC), 1)     AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late), 1)                    AS late_pct,
       ROUND(AVG(review_score), 2)                       AS avg_review
FROM v_delivered_orders
WHERE delivery_days IS NOT NULL
GROUP BY customer_state
ORDER BY late_rank;


-- Q10. Main payment method per order (largest payment, via ROW_NUMBER)
-- Insight: credit card 75.5%, boleto (bank slip) 19.9%, voucher 3.1%, debit card 1.5%.
WITH ranked_payments AS (
    SELECT p.order_id,
           p.payment_type,
           ROW_NUMBER() OVER (PARTITION BY p.order_id ORDER BY p.payment_value DESC, p.payment_sequential) AS rn
    FROM payments p
    JOIN orders o ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
)
SELECT payment_type,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM ranked_payments
WHERE rn = 1
GROUP BY payment_type
ORDER BY orders DESC;


-- Q11. Credit-card installments vs average order value
-- Insight: 68% of card orders use installments; 7-10 installment orders average R$333,
--          more than 3x single-payment orders (R$101).
WITH main_payment AS (
    SELECT order_id, payment_type,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC, payment_sequential) AS rn
    FROM payments
),
card_orders AS (
    SELECT d.order_id,
           d.order_value,
           MAX(GREATEST(p.payment_installments, 1)) AS installments
    FROM v_delivered_orders d
    JOIN main_payment mp ON mp.order_id = d.order_id AND mp.rn = 1 AND mp.payment_type = 'credit_card'
    JOIN payments p      ON p.order_id = d.order_id
    GROUP BY d.order_id, d.order_value
)
SELECT CASE
           WHEN installments = 1  THEN '1. Paid in full'
           WHEN installments <= 3 THEN '2. 2-3 installments'
           WHEN installments <= 6 THEN '3. 4-6 installments'
           WHEN installments <= 10 THEN '4. 7-10 installments'
           ELSE                        '5. 11+ installments'
       END                         AS installment_plan,
       COUNT(*)                    AS orders,
       ROUND(AVG(order_value), 2)  AS avg_order_value
FROM card_orders
GROUP BY 1
ORDER BY 1;


-- Q12. Repeat purchase rate (customer_unique_id, NOT customer_id)
-- Insight: only 3.0% of customers order again (2.2% on a later day), bringing 5.6% of revenue.
--          Using customer_id instead would wrongly show 0% repeat customers.
WITH per_customer AS (
    SELECT customer_unique_id,
           COUNT(*)                                             AS orders,
           COUNT(DISTINCT CAST(order_purchase_timestamp AS DATE)) AS purchase_days,
           SUM(order_value)                                     AS revenue
    FROM v_delivered_orders
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                                   AS customers,
       COUNT(*) FILTER (WHERE orders > 1)                         AS repeat_customers,
       ROUND(100.0 * AVG(CASE WHEN orders > 1 THEN 1 ELSE 0 END), 2)        AS repeat_rate_pct,
       ROUND(100.0 * AVG(CASE WHEN purchase_days > 1 THEN 1 ELSE 0 END), 2) AS returned_on_later_day_pct,
       ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN revenue ELSE 0 END) / SUM(revenue), 1) AS repeat_revenue_share_pct
FROM per_customer;


-- Q13. Month-1 retention by acquisition cohort
-- Insight: fewer than 1% of any cohort orders again in the following month (average ~0.5%).
WITH first_purchase AS (
    SELECT customer_unique_id,
           MIN(DATE_TRUNC('month', order_purchase_timestamp)) AS cohort_month
    FROM v_delivered_orders
    GROUP BY customer_unique_id
),
activity AS (
    SELECT DISTINCT d.customer_unique_id,
           f.cohort_month,
           DATE_TRUNC('month', d.order_purchase_timestamp) AS order_month
    FROM v_delivered_orders d
    JOIN first_purchase f ON f.customer_unique_id = d.customer_unique_id
)
SELECT CAST(cohort_month AS DATE) AS cohort_month,
       COUNT(DISTINCT customer_unique_id) FILTER (WHERE order_month = cohort_month)                      AS new_customers,
       COUNT(DISTINCT customer_unique_id) FILTER (WHERE order_month = cohort_month + INTERVAL '1 month') AS returned_next_month,
       ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE order_month = cohort_month + INTERVAL '1 month')
                   / COUNT(DISTINCT customer_unique_id) FILTER (WHERE order_month = cohort_month), 2) AS month_1_retention_pct
FROM activity
WHERE cohort_month BETWEEN DATE '2017-01-01' AND DATE '2018-07-01'
GROUP BY cohort_month
ORDER BY cohort_month;


-- Q14. Seller concentration: revenue by seller decile (NTILE)
-- Insight: the top 10% of sellers (297) generate 66.3% of revenue.
WITH seller_revenue AS (
    SELECT oi.seller_id,
           SUM(oi.price + oi.freight_value) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id AND o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
deciles AS (
    SELECT seller_id, revenue,
           NTILE(10) OVER (ORDER BY revenue DESC) AS seller_decile
    FROM seller_revenue
)
SELECT seller_decile,
       COUNT(*)            AS sellers,
       ROUND(SUM(revenue), 2) AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM deciles
GROUP BY seller_decile
ORDER BY seller_decile;


-- Q15. Top 3 categories in each of the 5 biggest states (ROW_NUMBER per partition)
-- Insight: bed_bath_table, health_beauty and watches_gifts lead in SP, RJ and MG;
--          PR leans to sports_leisure and RS to furniture_decor.
WITH top_states AS (
    SELECT customer_state, COUNT(*) AS state_orders
    FROM v_delivered_orders
    GROUP BY customer_state
    ORDER BY state_orders DESC
    LIMIT 5
),
state_category AS (
    SELECT d.customer_state,
           p.category,
           SUM(oi.price + oi.freight_value) AS revenue
    FROM v_delivered_orders d
    JOIN order_items oi ON oi.order_id = d.order_id
    JOIN v_products p   ON p.product_id = oi.product_id
    GROUP BY d.customer_state, p.category
),
ranked AS (
    SELECT sc.*,
           ROW_NUMBER() OVER (PARTITION BY sc.customer_state ORDER BY sc.revenue DESC) AS category_rank
    FROM state_category sc
)
SELECT r.customer_state,
       r.category_rank,
       r.category,
       ROUND(r.revenue, 2) AS revenue
FROM ranked r
JOIN top_states t ON t.customer_state = r.customer_state
WHERE r.category_rank <= 3
ORDER BY t.state_orders DESC, r.category_rank;
