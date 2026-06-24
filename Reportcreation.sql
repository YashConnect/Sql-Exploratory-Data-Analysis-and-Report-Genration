/*

Customer Report

Purpose:
- This report consolidates key customer metrics and behaviors

Highlights:
1. Gathers essential fields such as names, ages, and transaction details.
2. Segments customers into categories (VIP, Regular, New) and age groups.
3. Aggregates customer-level metrics:
- total orders
- total sales
- total quantity purchased
- total products
- lifespan (in months)
4. Calculates valuable KPIs:
- recency (months since last order)
- average order value
- average monthly spend

*/
-- ============================================================
-- GOLD LAYER REPORTING VIEWS
-- Purpose: Consolidated customer and product KPIs
-- ============================================================

-- ============================
-- Customer Report View
-- ============================

-- Q: Create a consolidated customer report with KPIs
CREATE VIEW Gold.Report AS
WITH base_query AS (
    SELECT 
        s.order_number,
        p.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name,' ',c.last_name) AS full_name,
        DATEDIFF(YEAR, c.birthday, GETDATE()) AS age
    FROM Gold.fact_sales s 
    LEFT JOIN Gold.dim_customers c ON c.customer_key = s.customer_key
    LEFT JOIN Gold.dim_products p ON p.product_key = s.product_key 
    WHERE s.order_date IS NOT NULL
),
customer_aggregation AS (
    SELECT 
        customer_key,
        customer_number,
        full_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, full_name, age
)
SELECT 
    customer_key,
    customer_number,
    full_name,
    age,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
    lifespan,
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    CASE 
        WHEN age < 20 THEN 'Below 20'
        WHEN age BETWEEN 20 AND 30 THEN '20-30'
        WHEN age BETWEEN 31 AND 40 THEN '31-40'
        ELSE 'Above 40'
    END AS age_group,
    total_sales / total_orders AS AOV,
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;

-- Explore the customer report
SELECT * FROM Gold.Report;

-- Aggregate by age group
SELECT 
    COUNT(*) AS total_customers, 
    SUM(total_sales) AS total_sales, 
    age_group
FROM Gold.Report
GROUP BY age_group;

/*
Product Report

Purpose:
- This report consolidates key product metrics and performance indicators.

Highlights:
1. Captures essential product attributes such as name, category, subcategory, and cost.
2. Segments products into performance tiers (High, Mid, Low) based on total sales.
3. Aggregates product-level metrics:
   - total orders
   - total sales
   - total quantity sold
   - total customers
   - lifespan (in months)
4. Calculates valuable KPIs:
   - recency (months since last sale)
   - average selling price
   - average order value
   - average monthly revenue
*/

-- ============================
-- Product Report View
-- ============================

-- Q: Create a consolidated product report with KPIs
CREATE VIEW Gold.report_product AS 
WITH basequery AS (
    SELECT 
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_cost
    FROM Gold.fact_sales f 
    LEFT JOIN Gold.dim_products p ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
),
post_agg AS (
    SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        product_cost,
        MAX(order_date) AS last_sale_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        COUNT(DISTINCT order_number) AS total_ord,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT customer_key) AS total_cust,
        ROUND(AVG(CAST(sales_amount AS FLOAT)) / SUM(quantity), 2) AS avg_selling
    FROM basequery
    GROUP BY product_key, product_name, category, subcategory, product_cost
)
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    product_cost,
    last_sale_date,
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS [recency_in_month],
    CASE 
        WHEN total_sales >= 100000 THEN 'High Performance'
        WHEN total_sales > 50000 THEN 'Mid Performer'
        ELSE 'Low Performer'
    END AS prod_segment,
    lifespan,
    total_ord,
    total_cust,
    total_quantity,
    total_sales,
    avg_selling,
    CASE 
        WHEN total_ord = 0 THEN 0
        ELSE total_sales / total_ord
    END AS avg_ord_value,
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM post_agg;

-- Explore the product report
SELECT * FROM Gold.report_product;