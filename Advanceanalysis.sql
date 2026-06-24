-- ============================================================
-- GOLD LAYER ADVANCED ANALYSIS SCRIPT
-- Purpose: Product performance, change over time, cumulative,
--          performance vs average, segmentation, part-to-whole,
--          and reporting views
-- ============================================================

-- ============================
-- Product Performance Analysis
-- ============================

-- Q: Which are the worst 5 performing products by revenue?
SELECT *
FROM (
    SELECT 
        p.product_name,
        SUM(f.sales_amount) AS Revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount)) AS Ranking
    FROM Gold.fact_sales f 
    LEFT JOIN Gold.dim_products p ON p.product_key = f.product_key
    GROUP BY p.product_name
) t
WHERE Ranking < 6;

-- Q: Which are the top 10 products by revenue?
SELECT TOP 10 
    p.product_name,
    SUM(f.sales_amount) AS Revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS Ranking
FROM Gold.fact_sales f 
LEFT JOIN Gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.product_name;

-- Q: Which are the lowest 3 products by total orders?
SELECT TOP 3 
    p.product_name,
    COUNT(DISTINCT order_number) AS Total_orders,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount)) AS Ranking
FROM Gold.fact_sales f 
LEFT JOIN Gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.product_name;

-- ============================
-- Change Over Time
-- ============================

-- Q: How do sales, customers, and quantity change year over year?
SELECT 
    DATETRUNC(YEAR, order_date) AS [year_over_year],
    SUM(sales_amount) AS Sales_amount,
    COUNT(DISTINCT customer_key) AS total_cust,
    SUM(quantity) AS total_quantity
FROM Gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
ORDER BY [year_over_year];

-- ============================
-- Cumulative Analysis
-- ============================

-- Q: What is the monthly sales trend with running totals and averages?
SELECT 
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total,
    AVG(AVGPRICE) OVER (ORDER BY order_date) AS running_avg
FROM (
    SELECT 
        DATETRUNC(MONTH, order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(unit_price) AS AVGPRICE
    FROM Gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
) t;

-- ============================
-- Performance Analysis
-- ============================

-- Q: How does product performance compare to average and previous year?
WITH yearly_product_sales AS (
    SELECT 
        YEAR(f.order_date) AS Year,
        p.product_name,
        SUM(sales_amount) AS TotalSales
    FROM Gold.fact_sales f 
    LEFT JOIN Gold.dim_products p ON p.product_key = f.product_key
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT 
    Year,
    product_name,
    TotalSales,
    AVG(TotalSales) OVER (PARTITION BY product_name) AS avg_sales,
    TotalSales - AVG(TotalSales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE 
        WHEN TotalSales - AVG(TotalSales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        ELSE 'Below Avg'
    END AS avg_change,
    LAG(TotalSales) OVER (PARTITION BY product_name ORDER BY Year) AS py_sales,
    TotalSales - LAG(TotalSales) OVER (PARTITION BY product_name ORDER BY Year) AS yoy_sales,
    CASE 
        WHEN TotalSales - LAG(TotalSales) OVER (PARTITION BY product_name ORDER BY Year) > 0 THEN 'Increasing'
        WHEN TotalSales - LAG(TotalSales) OVER (PARTITION BY product_name ORDER BY Year) < 0 THEN 'Decreasing'
        ELSE 'Same'
    END AS py_sales_change
FROM yearly_product_sales
ORDER BY product_name, Year;

-- ============================
-- Part-to-Whole Analysis
-- ============================

-- Q: What percentage of total sales does each category contribute?
SELECT 
    p.category,
    SUM(s.sales_amount) AS category_sales,
    SUM(SUM(s.sales_amount)) OVER() AS total_sales,
    CONCAT(
        ROUND(
            (CAST(SUM(s.sales_amount) AS FLOAT) / SUM(SUM(s.sales_amount)) OVER()) * 100, 2
        ), '%'
    ) AS percentage
FROM Gold.fact_sales s
LEFT JOIN Gold.dim_products p ON s.product_key = p.product_key 
GROUP BY p.category;

-- ============================
-- Data Segmentation
-- ============================

-- Q: How many products fall into each cost segment?
SELECT segment, COUNT(*) AS total_products
FROM (
    SELECT 
        product_name,
        product_cost,
        CASE 
            WHEN product_cost > 0 AND product_cost <= 100 THEN 'Below 100'
            WHEN product_cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN product_cost BETWEEN 501 AND 1000 THEN '501-1000'
            ELSE 'Above 1000'
        END AS segment
    FROM Gold.dim_products
) t
GROUP BY segment
ORDER BY total_products DESC;

-- Q: How many customers fall into VIP, Regular, or New segments?
WITH customer_spending AS (
    SELECT 
        c.customer_key,
        SUM(s.sales_amount) AS total_sales,
        MIN(s.order_date) AS first_order,
        MAX(s.order_date) AS last_order,
        DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS lifespan,
        CASE 
            WHEN DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) >= 12 AND SUM(s.sales_amount) > 5000 THEN 'VIP'
            WHEN DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) >= 12 AND SUM(s.sales_amount) <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM Gold.fact_sales s 
    LEFT JOIN Gold.dim_customers c ON c.customer_key = s.customer_key
    GROUP BY c.customer_key
)
SELECT customer_segment, COUNT(*) AS total_cust
FROM customer_spending
GROUP BY customer_segment
ORDER BY total_cust DESC;