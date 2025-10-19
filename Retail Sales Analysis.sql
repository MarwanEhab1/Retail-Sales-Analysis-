
--  Total yearly sales, unique customers, and quantity

SELECT 
    YEAR(order_date) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);


--  Monthly breakdown of sales, customers, and quantity

SELECT 
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);


--  Monthly Sales Summary (formatted yyyy-MM)


SELECT  
    FORMAT(order_date, 'yyyy-MM') AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales 
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MM');


-- Monthly Running Total of Sales

SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER(ORDER BY order_month) AS running_total_sales
FROM (
    SELECT 
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
        SUM(sales_amount) AS total_sales
    FROM fact_sales 
    WHERE order_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
) AS monthly_sales
ORDER BY order_month;


-- Products with cost above category average

SELECT *
FROM (
    SELECT
        category,
        cost,
        AVG(cost) OVER(PARTITION BY category) AS avg_cost
    FROM products
    WHERE category IS NOT NULL
) AS sub
WHERE cost > avg_cost;


-- Check cost trend by category using LEAD

SELECT
    category,
    cost,
    LEAD(cost) OVER(ORDER BY category) AS next_cost
FROM products 
WHERE category IS NOT NULL;


-- Top 3 best-selling products per category

WITH ranked_products AS (
    SELECT
        p.category,
        p.product_name,
        SUM(s.sales_amount) AS total_sales,
        RANK() OVER (PARTITION BY p.category ORDER BY SUM(s.sales_amount) DESC) AS rnk
    FROM fact_sales s
    JOIN products p ON s.product_key = p.product_key
    GROUP BY p.category, p.product_name
)
SELECT *
FROM ranked_products
WHERE rnk <= 3;


--  Monthly sales trend with previous month comparison

WITH monthly_product_sales AS (
    SELECT
        FORMAT(order_date,'yyyy-MM') AS order_month,
        SUM(sales_amount) AS monthly_sales,
        product_name
    FROM fact_sales s
    JOIN products p ON p.product_key = s.product_key
    GROUP BY FORMAT(order_date,'yyyy-MM'), product_name
)
SELECT *,
    LAG(monthly_sales) OVER (PARTITION BY product_name ORDER BY order_month) AS prev_month_sales,
    monthly_sales - LAG(monthly_sales) OVER (PARTITION BY product_name ORDER BY order_month) AS change_from_prev
FROM monthly_product_sales;


--  Customer segmentation based on total sales vs average

WITH customer_segment AS (
    SELECT 
        customer_name,
        SUM(total_sales) AS total_sales,
        AVG(SUM(total_sales)) OVER () AS avg_sales
    FROM customers
    GROUP BY customer_name
)
SELECT *,
    CASE
        WHEN total_sales > avg_sales THEN 'above_avg'
        ELSE 'below_avg'
    END AS sales_segment
FROM customer_segment;


-- Best-selling product in each category

WITH ranked_products AS (
    SELECT 
        category,
        product_name,
        SUM(sales_amount) AS total_sales,
        RANK() OVER(PARTITION BY category ORDER BY SUM(sales_amount) DESC) AS top_rank
    FROM fact_sales s
    JOIN products p ON p.product_key = s.product_key
    GROUP BY category, product_name
)
SELECT * 
FROM ranked_products
WHERE top_rank = 1;


-- Categories with sales above overall average

WITH category_stats AS (
    SELECT
        category,
        SUM(sales_amount) AS total_sales,
        AVG(SUM(sales_amount)) OVER () AS avg_category_sales
    FROM fact_sales s
    JOIN products p ON p.product_key = s.product_key
    GROUP BY category
)
SELECT *,
    total_sales - avg_category_sales AS diff_from_avg
FROM category_stats
WHERE total_sales > avg_category_sales;


-- Average sales per customer per category

SELECT
    p.category,
    c.customer_name,
    AVG(s.sales_amount) AS avg_sales
FROM fact_sales s
JOIN products p ON p.product_key = s.product_key
JOIN customers c ON s.customer_key = c.customer_key
GROUP BY p.category, c.customer_name
ORDER BY avg_sales DESC;


--  Customer ranking by total sales

SELECT
    c.customer_name,
    COUNT(DISTINCT s.order_number) AS total_orders,
    SUM(s.sales_amount) AS total_sales,
    RANK() OVER (ORDER BY SUM(s.sales_amount) DESC) AS sales_rank
FROM fact_sales s
JOIN customers c ON c.customer_key = s.customer_key
GROUP BY c.customer_name;


--  Top 10 highest-spending customers

SELECT TOP 10
    customer_name,
    total_sales
FROM customers
ORDER BY total_sales DESC;


--  Total orders per customer age group

SELECT 
    age_group,
    SUM(total_orders) AS total_orders
FROM customers
GROUP BY age_group;


--  Which categories contribute most to overall sales

WITH category_sales AS (
    SELECT 
        category,
        SUM(sales_amount) AS total_sales
    FROM products p
    JOIN fact_sales s ON p.product_key = s.product_key
    GROUP BY category
)
SELECT *,
    SUM(total_sales) OVER() AS overall_sales,
    CONCAT(ROUND(CAST(total_sales AS FLOAT) / SUM(total_sales) OVER () * 100, 2), '%') AS percentage_of_total_sales
FROM category_sales;


--  Segment products by cost range

WITH product_segment AS (
    SELECT 
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM products
)
SELECT 
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC;


-- Customer segmentation based on spending and lifespan

WITH customer_spending AS (
    SELECT 
        c.customer_key,
        SUM(sales_amount) AS total_spending,
        MIN(order_date) AS first_date,
        MAX(order_date) AS last_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM fact_sales s
    LEFT JOIN customers c ON c.customer_key = s.customer_key
    GROUP BY c.customer_key
)
SELECT *,
    CASE
        WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment
FROM customer_spending;


--  Count of customers by segment type

WITH customer_spending AS (
    SELECT 
        c.customer_key,
        SUM(sales_amount) AS total_spending,
        MIN(order_date) AS first_date,
        MAX(order_date) AS last_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM fact_sales s
    LEFT JOIN customers c ON c.customer_key = s.customer_key
    GROUP BY c.customer_key
)
SELECT 
    COUNT(customer_key) AS total_customers,
    customer_segment
FROM (
    SELECT *,
        CASE
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment 
    FROM customer_spending
) AS classified_customers
GROUP BY customer_segment;


-- Create a detailed view for customer analytics

CREATE VIEW customers_details AS
WITH base_query AS (
    SELECT 
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM fact_sales AS s
    LEFT JOIN report_customers AS c ON c.customer_key = s.customer_key
    WHERE order_date IS NOT NULL
),
customer_aggregation AS (
    SELECT 
        customer_key,
        customer_number,
        full_name,
        age,
        COUNT(DISTINCT order_number) AS total_order,
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
    total_order,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
    total_sales / total_order AS avg_order_value,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_month_spend
FROM customer_aggregation;