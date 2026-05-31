-- Question 1: Coffee Consumer Estimate
/* Assuming 25% of each city's population drinks coffee, calculate the estimated number of 
coffee consumers (in millions) per city.Order results from highest to lowest. */

-- Calculating 25% of population to find estimated coffee consumers in millions
SELECT 
    city_name,
    population,
    ROUND((population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions
FROM 
    city
ORDER BY 
    estimated_coffee_consumers_millions DESC;

-- Question 2: Total Revenue Q4 2023
/* What is the total revenue generated from coffee sales across all cities during the
last quarter of 2023 (October-December)?Show results per city, ordered by revenue descending. */

-- Joining sales, customers, and cities to filter by Q4 2023 and sum total revenue
SELECT 
    ci.city_name,
    SUM(s.total) AS total_revenue_q4
FROM 
    sales s
JOIN 
    customers cu ON s.customer_id = cu.customer_id
JOIN 
    city ci ON cu.city_id = ci.city_id
WHERE 
    s.sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY 
    ci.city_name
ORDER BY 
    total_revenue_q4 DESC;

-- Question 3: Sales Volume by Product
/* How many units of each coffee product have been sold in total? 
Rank products from best-selling to least-selling. */

-- Counting total quantity sold per product using COUNT 
-- (Assuming each row in sales represents 1 unit sold based on  row sample)
SELECT
    p.product_name,
    COUNT(s.sale_id) AS units_sold
FROM 
    sales s
JOIN 
    products p ON s.product_id = p.product_id
GROUP BY 
    p.product_name
ORDER BY 
    units_sold DESC;

-- Question 4: Average Sales per Customer by City
/* What is the average total sales amount per unique customer in each city? Include total revenue 
and customer count alongside the average. Order by total revenue descending. */

-- Calculating total revenue, unique customers, and average spending per customer per city
SELECT
    ci.city_name,
    SUM(s.total)  AS total_revenue,
    COUNT(DISTINCT s.customer_id)  AS total_customers,
    ROUND(SUM(s.total)::NUMERIC / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_per_customer
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
JOIN city ci     ON c.city_id     = ci.city_id
GROUP BY ci.city_name
ORDER BY total_revenue DESC;

-- Question 5: Current Customers vs. Estimated Coffee Consumers
/* For each city, show both the estimated coffee-drinking population (25% of city population, in millions) 
and the actual number of unique customers from the sales data. Use a CTE. */

-- Using a Common Table Expression (CTE) to join aggregated sales metrics with city population estimations
WITH city_sales AS (
    SELECT 
        cu.city_id,
        COUNT(DISTINCT s.customer_id) AS unique_customers
    FROM 
        sales s
    JOIN 
        customers cu ON s.customer_id = cu.customer_id
    GROUP BY 
        cu.city_id
)
SELECT 
    ci.city_name,
    ROUND((ci.population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions,
    COALESCE(cs.unique_customers, 0) AS actual_unique_customers
FROM 
    city ci
LEFT JOIN 
    city_sales cs ON ci.city_id = cs.city_id
ORDER BY 
    actual_unique_customers DESC;

-- Question 6: Top 3 Products per City
/* What are the top 3 best-selling coffee products in each city, based on number of orders? 
Use a window function to rank products within each city. */

-- Using DENSE_RANK() window function to identify the top 3 products ordered per city
WITH ranked_products AS (
    SELECT 
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS order_count,
        DENSE_RANK() OVER (PARTITION BY ci.city_name ORDER BY COUNT(s.sale_id) DESC) as product_rank
    FROM 
        sales s
    JOIN 
        products p ON s.product_id = p.product_id
    JOIN 
        customers cu ON s.customer_id = cu.customer_id
    JOIN 
        city ci ON cu.city_id = ci.city_id
    GROUP BY 
        ci.city_name, p.product_name
)
SELECT 
    city_name,
    product_name,
    order_count,
    product_rank
FROM 
    ranked_products
WHERE 
    product_rank <= 3;

-- Question 7: Unique Customers per City
/* How many unique customers in each city have made at least one coffee purchase? 
Order by customer count descending. */

-- Counting distinct customers who have records in the sales table grouped by city
SELECT 
    ci.city_name,
    COUNT(DISTINCT s.customer_id) AS unique_buying_customers
FROM 
    sales s
JOIN 
    customers cu ON s.customer_id = cu.customer_id
JOIN 
    city ci ON cu.city_id = ci.city_id
GROUP BY 
    ci.city_name
ORDER BY 
    unique_buying_customers DESC;

-- Question 8: Average Sale vs. Average Rent per Customer
/* For each city, compare the average sale amount per customer against the average rent cost per customer
(estimated_rent divided by number of customers). This helps evaluate cost efficiency. */

-- Comparing sales revenue efficiency against city commercial rent costs per customer
SELECT 
    ci.city_name,
    -- Cast the division result to numeric, then round it
    ROUND((SUM(s.total) / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_sale_per_customer,
    ROUND((ci.estimated_rent / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci      ON cu.city_id = ci.city_id
GROUP BY ci.city_name, ci.estimated_rent
ORDER BY avg_sale_per_customer DESC;

-- Question 9: Month-on-Month Sales Growth
/* Calculate the month-on-month percentage change in total sales for each city.
Use a window function (LAG) to compare each month's sales to the previous month. Show only rows where a prior month exists. */

-- Using LAG() to compare current month sales to previous month sales per city
WITH monthly_sales AS (
    SELECT 
        ci.city_name,
        EXTRACT(YEAR FROM s.sale_date) AS sales_year,
        EXTRACT(MONTH FROM s.sale_date) AS sales_month,
        SUM(s.total) AS total_sales
    FROM sales s
    JOIN customers cu ON s.customer_id = cu.customer_id
    JOIN city ci      ON cu.city_id = ci.city_id
    GROUP BY ci.city_name, EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
),
sales_with_lag AS (
    SELECT 
        city_name,
        sales_year,
        sales_month,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY city_name ORDER BY sales_year, sales_month) AS prev_month_sales
    FROM monthly_sales
)
SELECT 
    city_name,
    sales_year,
    sales_month,
    total_sales,
    prev_month_sales,
    -- Wrap the full calculation in parentheses and add ::numeric before the comma
    ROUND((((total_sales - prev_month_sales) / prev_month_sales) * 100)::NUMERIC, 2) AS mom_growth_percentage
FROM sales_with_lag
WHERE prev_month_sales IS NOT NULL;

-- Question 10: Market Potential Summary

-- Comprehensive Master Market Table combining volume, revenue, customer data, and rental overheads
SELECT 
    ci.city_name,
    SUM(s.total) AS total_revenue,
    ci.estimated_rent,
    COUNT(DISTINCT s.customer_id) AS total_customers,
    ROUND((ci.population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions,
    -- Added explicit type cast (::NUMERIC) to the division results
    ROUND((SUM(s.total) / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_sale_per_customer,
    ROUND((ci.estimated_rent / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci      ON cu.city_id = ci.city_id
GROUP BY ci.city_name, ci.estimated_rent, ci.population
ORDER BY total_revenue DESC;


-- Bonus Questions 1
/* What is the average rating given by customers in each city, 
and does higher revenue correlate with a higher store rating? */

-- Find average customer satisfaction rating per city
SELECT 
	ci.city_name, 
	ROUND(AVG(s.rating), 2) AS avg_customer_rating, 
	SUM(s.total) as total_revenue
FROM sales s 
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
GROUP BY ci.city_name 
ORDER BY avg_customer_rating DESC;

-- Interpretation: Cities with higher average ratings indicate stronger customer satisfaction, making them safer bets for physical store investment.

-- Bonus Questions 2 
/* Which product generates the most revenue per city? */

-- Identify top revenue-generating product in each city
WITH product_revenue AS (
    SELECT
        ci.city_name,
        p.product_name,
        SUM(s.total)  AS product_revenue,
        RANK() OVER (PARTITION BY ci.city_name ORDER BY SUM(s.total) DESC) AS rank
    FROM sales s
    JOIN customers c ON s.customer_id = c.customer_id
    JOIN city ci     ON c.city_id     = ci.city_id
    JOIN products p  ON s.product_id  = p.product_id
    GROUP BY ci.city_name, p.product_name
)
SELECT city_name, product_name, product_revenue
FROM product_revenue
WHERE rank = 1
ORDER BY product_revenue DESC;

-- Interpretation: Knowing the top revenue product per city allows Monday Coffee to prioritise stocking and promoting that product in the physical store.


-- Bonus Question 3 
/* What are the peak sales months globally for Monday Coffee to determine
when a physical launch event would be most profitable? */

SELECT 
    EXTRACT(MONTH FROM sale_date) AS month_num,
    TO_CHAR(sale_date, 'Month')  AS month_name,
    SUM(total) AS monthly_revenue
FROM sales
GROUP BY month_num, month_name
ORDER BY monthly_revenue DESC;

/* Interpretation: Monday Coffee should leverage its peak online sales periods 
by planning a physical store soft opening in February to stabilize operations just before the major March demand surge, 
while eyeing the highly lucrative fourth-quarter festive season as a prime secondary launch window. */

-- BUSINESS RECOMMENDATION 
-- Identify the three cities you would recommend for Monday Coffee's first physical store locations and justify each choice using specific metrics from your queries.

-- CITY 1: PUNE (PRIORITY 1)
/* Pune is the strongest city across all analyzed metrics and should be the top priority. It leads all 14 cities in total revenue at 1,258,290 
and has the highest average sale per customer at 24,197.88, which proves that local customers are already high spenders. It is also highly cost-efficient 
because its average rent per customer is only 294.23, which is the second lowest among the top five revenue-generating cities. With 52 unique customers and 
an estimated 1.88 million potential coffee consumers, Pune offers a massive untapped market. Finally, its strong customer satisfaction rating of 4.47 out of 5 
confirms that the brand already has a highly loyal local base. */


-- CITY 2: CHENNAI (PRIORITY 2)
/* Chennai is an outstanding expansion candidate, ranking second in total revenue at 944,120 and delivering the highest customer satisfaction rating in the entire dataset at
4.52 out of 5, which signals incredible brand loyalty. The city boasts a strong average sale per customer of 22,479.05 alongside a highly manageable average rent per customer of 407.14, 
ensuring a healthy revenue-to-rent ratio. Furthermore, while Chennai has an estimated 2.78 million potential coffee consumers, it currently has only 42 unique customers. This represents the 
largest gap between market potential and brand penetration among all top-tier cities, proving that a physical footprint could unlock massive, untapped demand. This combination of unmatched 
customer satisfaction and enormous volume upside makes Chennai a exceptionally low-risk, high-reward market. */ 

-- CITY 3: BANGALORE (PRIORITY 3)
/* Bangalore is a premier choice for expansion, ranking third in total revenue at 860,110 and boasting the largest estimated coffee consumer base among the top three cities at 3.08 million—the highest
untapped volume potential of any recommended location. The market demonstrates exceptional strength with a high average sale per customer of 22,054.10 and a stellar customer satisfaction rating of 4.48 out of 5, 
which stands as the second-highest overall. While the city requires a higher real estate investment—evidenced by an average rent per customer of 761.54 compared to Pune and Chennai—this overhead is thoroughly justified by 
the sheer scale of the consumer base and robust top-line revenue performance. Ultimately, Bangalore’s affluent, tech-savvy demographic and established coffee-culture make it an ideal, high-yielding fit for a premium physical storefront. */
