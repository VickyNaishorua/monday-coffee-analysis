# Monday Coffee -- Business Expansion Analysis
### SQL Capstone Project | PostgreSQL 18

**Author:** Vicky Naishorua  
**Date:** May 2026  
**Tool:** PostgreSQL 18 via pgAdmin  
**Database:** `monday_coffee`

---

## Problem Statement

Monday Coffee is a fictional coffee brand that has been selling its products online across multiple Indian cities since January 2023. The company is now looking to expand into physical store locations and needs to make data-driven decisions about where to open.

As the Data Analyst for Monday Coffee, the objective of this project is to analyse sales, customer, and city data using SQL to identify the **top three Indian cities** best suited for new physical coffee shop locations, based on revenue performance, customer behaviour, rent efficiency, and market potential.

---

## Data Description

The dataset consists of four CSV files imported into PostgreSQL:

| Table | File | Description |
|---|---|---|
| `city` | city.csv | City population, estimated rent, and city rank |
| `products` | products.csv | Coffee product names and prices |
| `customers` | customers.csv | Customer records linked to cities |
| `sales` | sales.csv | All sales transactions (10,389 rows) |

### Table Schemas

**city**

| Column | Type | Notes |
|---|---|---|
| city_id | integer | Primary Key |
| city_name | varchar(50) | |
| population | bigint | |
| estimated_rent | double precision | |
| city_rank | integer | |

**customers**

| Column | Type | Notes |
|---|---|---|
| customer_id | integer | Primary Key |
| customer_name | varchar(100) | |
| city_id | integer | Foreign Key -> city.city_id |

**products**

| Column | Type | Notes |
|---|---|---|
| product_id | integer | Primary Key |
| product_name | varchar(100) | |
| price | double precision | |

**sales**

| Column | Type | Notes |
|---|---|---|
| sale_id | integer | Primary Key |
| sale_date | date | |
| customer_id | integer | Foreign Key -> customers.customer_id |
| product_id | integer | Foreign Key -> products.product_id |
| total | double precision | |
| rating | integer | |

### Entity Relationship Diagram

The four tables are linked through the following relationships, as defined in the pgAdmin ERD:

![ERD](https://i.postimg.cc/jSwky5yP/Screenshot-2026-05-31-110545.png)

**Relationship summary:**

- `city.city_id` (PK) -- one-to-many -- `customers.city_id` (FK): one city has many customers
- `customers.customer_id` (PK) -- one-to-many -- `sales.customer_id` (FK): one customer has many sales
- `products.product_id` (PK) -- one-to-many -- `sales.product_id` (FK): one product appears in many sales

---

## Methodology

All analysis was performed using **PostgreSQL 18**. Queries were written and tested in pgAdmin's Query Tool. The full script is available in [`Vicky_Naishorua_Monday_Coffee_Analysis_.sql`](./Vicky_Naishorua_Monday_Coffee_Analysis_.sql).

---

### Question 1 -- Coffee Consumer Estimate

> Assuming 25% of each city's population drinks coffee, calculate the estimated number of coffee consumers (in millions) per city.

```sql
SELECT 
    city_name,
    population,
    ROUND((population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions
FROM city
ORDER BY estimated_coffee_consumers_millions DESC;
```

---

### Question 2 -- Total Revenue Q4 2023

> What is the total revenue generated from coffee sales across all cities during Q4 2023 (October-December)?

```sql
SELECT 
    ci.city_name,
    SUM(s.total) AS total_revenue_q4
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
WHERE s.sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY ci.city_name
ORDER BY total_revenue_q4 DESC;
```

---

### Question 3 -- Sales Volume by Product

> How many units of each coffee product have been sold in total?

```sql
SELECT
    p.product_name,
    COUNT(s.sale_id) AS units_sold
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY units_sold DESC;
```

---

### Question 4 -- Average Sales per Customer by City

> What is the average total sales amount per unique customer in each city?

```sql
SELECT
    ci.city_name,
    SUM(s.total) AS total_revenue,
    COUNT(DISTINCT s.customer_id) AS total_customers,
    ROUND(SUM(s.total)::NUMERIC / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_per_customer
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
JOIN city ci ON c.city_id = ci.city_id
GROUP BY ci.city_name
ORDER BY total_revenue DESC;
```

---

### Question 5 -- Current Customers vs. Estimated Coffee Consumers (CTE)

> For each city, compare estimated coffee-drinking population against actual unique customers.

```sql
WITH city_sales AS (
    SELECT 
        cu.city_id,
        COUNT(DISTINCT s.customer_id) AS unique_customers
    FROM sales s
    JOIN customers cu ON s.customer_id = cu.customer_id
    GROUP BY cu.city_id
)
SELECT 
    ci.city_name,
    ROUND((ci.population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions,
    COALESCE(cs.unique_customers, 0) AS actual_unique_customers
FROM city ci
LEFT JOIN city_sales cs ON ci.city_id = cs.city_id
ORDER BY actual_unique_customers DESC;
```

---

### Question 6 -- Top 3 Products per City (Window Function)

> What are the top 3 best-selling coffee products in each city, based on number of orders?

```sql
WITH ranked_products AS (
    SELECT 
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS order_count,
        DENSE_RANK() OVER (PARTITION BY ci.city_name ORDER BY COUNT(s.sale_id) DESC) AS product_rank
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    JOIN customers cu ON s.customer_id = cu.customer_id
    JOIN city ci ON cu.city_id = ci.city_id
    GROUP BY ci.city_name, p.product_name
)
SELECT city_name, product_name, order_count, product_rank
FROM ranked_products
WHERE product_rank <= 3;
```

---

### Question 7 -- Unique Customers per City

> How many unique customers in each city have made at least one coffee purchase?

```sql
SELECT 
    ci.city_name,
    COUNT(DISTINCT s.customer_id) AS unique_buying_customers
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
GROUP BY ci.city_name
ORDER BY unique_buying_customers DESC;
```

---

### Question 8 -- Average Sale vs. Average Rent per Customer

> For each city, compare average sale amount per customer against average rent cost per customer.

```sql
SELECT 
    ci.city_name,
    ROUND((SUM(s.total) / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_sale_per_customer,
    ROUND((ci.estimated_rent / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
GROUP BY ci.city_name, ci.estimated_rent
ORDER BY avg_sale_per_customer DESC;
```

---

### Question 9 -- Month-on-Month Sales Growth (LAG Window Function)

> Calculate the month-on-month percentage change in total sales for each city.

```sql
WITH monthly_sales AS (
    SELECT 
        ci.city_name,
        EXTRACT(YEAR FROM s.sale_date) AS sales_year,
        EXTRACT(MONTH FROM s.sale_date) AS sales_month,
        SUM(s.total) AS total_sales
    FROM sales s
    JOIN customers cu ON s.customer_id = cu.customer_id
    JOIN city ci ON cu.city_id = ci.city_id
    GROUP BY ci.city_name, EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
),
sales_with_lag AS (
    SELECT 
        city_name, sales_year, sales_month, total_sales,
        LAG(total_sales) OVER (PARTITION BY city_name ORDER BY sales_year, sales_month) AS prev_month_sales
    FROM monthly_sales
)
SELECT 
    city_name, sales_year, sales_month, total_sales, prev_month_sales,
    ROUND((((total_sales - prev_month_sales) / prev_month_sales) * 100)::NUMERIC, 2) AS mom_growth_percentage
FROM sales_with_lag
WHERE prev_month_sales IS NOT NULL;
```

---

### Question 10 -- Market Potential Summary

> Full market overview per city combining all key metrics.

```sql
SELECT 
    ci.city_name,
    SUM(s.total) AS total_revenue,
    ci.estimated_rent,
    COUNT(DISTINCT s.customer_id) AS total_customers,
    ROUND((ci.population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions,
    ROUND((SUM(s.total) / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_sale_per_customer,
    ROUND((ci.estimated_rent / COUNT(DISTINCT s.customer_id))::NUMERIC, 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
GROUP BY ci.city_name, ci.estimated_rent, ci.population
ORDER BY total_revenue DESC;
```

---

### Bonus Question 1 -- Customer Satisfaction vs Revenue

> What is the average rating given by customers in each city, and does higher revenue correlate with higher satisfaction?

```sql
SELECT 
    ci.city_name, 
    ROUND(AVG(s.rating), 2) AS avg_customer_rating, 
    SUM(s.total) AS total_revenue
FROM sales s 
JOIN customers cu ON s.customer_id = cu.customer_id
JOIN city ci ON cu.city_id = ci.city_id
GROUP BY ci.city_name 
ORDER BY avg_customer_rating DESC;
```

**Interpretation:** Cities with higher average ratings indicate stronger customer satisfaction, making them safer bets for physical store investment.

---

### Bonus Question 2 -- Top Revenue Product per City

> Which product generates the most revenue in each city?

```sql
WITH product_revenue AS (
    SELECT
        ci.city_name,
        p.product_name,
        SUM(s.total) AS product_revenue,
        RANK() OVER (PARTITION BY ci.city_name ORDER BY SUM(s.total) DESC) AS rank
    FROM sales s
    JOIN customers c ON s.customer_id = c.customer_id
    JOIN city ci ON c.city_id = ci.city_id
    JOIN products p ON s.product_id = p.product_id
    GROUP BY ci.city_name, p.product_name
)
SELECT city_name, product_name, product_revenue
FROM product_revenue
WHERE rank = 1
ORDER BY product_revenue DESC;
```

**Interpretation:** Knowing the top revenue product per city allows Monday Coffee to prioritise stocking and promoting that product in the physical store.

---

### Bonus Question 3 -- Peak Sales Months Globally

> What are the peak sales months globally to determine when a physical launch event would be most profitable?

```sql
SELECT 
    EXTRACT(MONTH FROM sale_date) AS month_num,
    TO_CHAR(sale_date, 'Month') AS month_name,
    SUM(total) AS monthly_revenue
FROM sales
GROUP BY month_num, month_name
ORDER BY monthly_revenue DESC;
```

**Interpretation:** Monday Coffee should plan a soft opening in February to stabilise operations just before the major March demand surge (Rs. 724,170), while targeting the Q4 festive season (October-December) as a prime secondary launch window.

---

### Q10 Market Potential Summary Output

| City | Total Revenue | Est. Rent | Customers | Est. Consumers (M) | Avg Sale/Customer | Avg Rent/Customer |
|---|---|---|---|---|---|---|
| Pune | Rs. 1,258,290 | Rs. 15,300 | 52 | 1.88M | Rs. 24,197.88 | Rs. 294.23 |
| Chennai | Rs. 944,120 | Rs. 17,100 | 42 | 2.78M | Rs. 22,479.05 | Rs. 407.14 |
| Bangalore | Rs. 860,110 | Rs. 29,700 | 39 | 3.08M | Rs. 22,054.10 | Rs. 761.54 |
| Jaipur | Rs. 803,450 | Rs. 10,800 | 69 | 1.00M | Rs. 11,644.20 | Rs. 156.52 |
| Delhi | Rs. 750,420 | Rs. 22,500 | 68 | 7.75M | Rs. 11,035.59 | Rs. 330.88 |

---

## SQL Concepts Used

| Concept | Questions Applied |
|---|---|
| `SELECT`, `GROUP BY`, `ORDER BY` | Q1, Q2, Q3, Q7 |
| `JOIN` (INNER, LEFT) | Q2, Q4, Q5, Q6, Q7, Q8, Q10 |
| Aggregate functions (`SUM`, `COUNT`, `AVG`) | Q2, Q3, Q4, Q7, Q8, Q10 |
| `ROUND()` with `::NUMERIC` cast | Q1, Q4, Q8, Q10 |
| `WHERE` with date filtering (`BETWEEN`) | Q2 |
| `DISTINCT` | Q4, Q5, Q7 |
| Common Table Expressions (`WITH` / CTE) | Q5, Q6, Q9, Bonus Q2 |
| Window Functions (`DENSE_RANK`, `RANK`, `LAG`) | Q6, Q9, Bonus Q2 |
| `PARTITION BY` | Q6, Q9, Bonus Q2 |
| `EXTRACT()` for date parts | Q9, Bonus Q3 |
| `TO_CHAR()` for date formatting | Bonus Q3 |
| `COALESCE()` for null handling | Q5 |

---

## Key Insights and Recommendations

### Top 3 Recommended Cities

#### 1. Pune -- Priority 1

Pune is the strongest candidate across every metric. It leads all 14 cities in total revenue at Rs. 1,258,290 and records the highest average sale per customer at Rs. 24,197.88, proving that local customers are already high spenders. Its average rent per customer of Rs. 294.23 is the second lowest among the top five revenue cities, making it the most cost-efficient market to enter. With 52 unique customers against an estimated 1.88 million coffee consumers, there is substantial untapped potential. A strong satisfaction rating of 4.47 out of 5 confirms existing brand loyalty.

#### 2. Chennai -- Priority 2

Chennai ranks second in total revenue at Rs. 944,120 and holds the highest customer satisfaction rating of 4.52 out of 5 in the entire dataset, the strongest signal of brand loyalty. Its average sale per customer stands at Rs. 22,479.05 with a manageable rent per customer of Rs. 407.14. Most importantly, with an estimated 2.78 million consumers but only 42 actual customers, Chennai represents the largest gap between market potential and brand penetration among top-tier cities. A physical store could unlock enormous untapped demand.

#### 3. Bangalore -- Priority 3

Bangalore ranks third in revenue at Rs. 860,110 and has the largest estimated coffee consumer base of 3.08 million among all recommended cities. Its average sale per customer is strong at Rs. 22,054.10 and customer satisfaction is 4.48 out of 5, the second highest overall. While rent per customer is higher at Rs. 761.54, this is justified by the scale of the consumer base and Bangalore's established premium coffee culture.

### Why Not Jaipur or Delhi?

Despite having more customers (69 and 68 respectively), Jaipur and Delhi show average sales per customer of only Rs. 11,644 and Rs. 11,035, less than half of the top three cities. This suggests price-sensitive markets where Monday Coffee's premium positioning may face resistance.

### Launch Timing

March is the peak global sales month at Rs. 724,170. A soft opening in February would allow operations to stabilise before the March surge. October-November represents a strong secondary launch window driven by the festive season.

---

## Limitations and Future Work

### Limitations

- No quantity column in the sales table. Each row was assumed to represent one unit sold, which may undercount high-volume orders.
- Static rent data. The `estimated_rent` column is a fixed estimate and may not reflect real-time commercial property prices.
- Limited time window. Data covers January 2023 to early 2024, which may not capture long-term seasonal trends reliably.
- No demographic data. Age, income level, or occupation of customers is unavailable, limiting segmentation analysis.
- Online-only baseline. All existing sales are digital; physical store behaviour such as foot traffic and impulse purchases may differ significantly.

### Future Work

- Incorporate real estate market data via external APIs to validate rent estimates.
- Add customer demographic data to refine targeting for physical store locations.
- Perform cohort analysis to track customer lifetime value over time per city.
- Build a dashboard in Power BI or Tableau using these SQL outputs for executive-level reporting.
- Expand analysis to include competitor density per city to assess market saturation.

---

*Capstone Project -- Data Analysis with SQL | May 2026*
