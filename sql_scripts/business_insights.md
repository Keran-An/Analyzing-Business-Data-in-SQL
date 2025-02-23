# Introduction to Business Insights Analysis
In the Business Insights section, we move beyond general exploration to perform deeper, actionable analyses. Here, our goal is to leverage SQL to extract detailed insights that directly support strategic business decisions. The analyses conducted here focus on profitability, customer behavior, retention, and segmentation—essential factors for business growth.

# Table of Contents
- [Revenue, Cost, and Profit](#revenue-cost-and-profit)
	- [Profit per Eatery](#profit-per-eatery)
- [User-Centric KPIs](#user-centric-kpis)
	- [Retention Rate](#retention-rate)
- [ARPU, Histograms, and Percentiles](#arpu-histograms-and-percentiles)
	- [Bucketing Users by Revenue/Orders](#bucketing-users-by-revenue-orders)
	- [Revenue Quartiles](#revenue-quartiles)
	- [Interquartile Range](#interquartile-range)
- [Generating an Executive Report](#generating-an-executive-report)
	- [Rank Users by Their Count of Orders](#rank-users-by-their-count-of-orders)
	- [Pivoting User Revenue by Month](#pivoting-user-revenue-by-month)
	- [Costs](#costs)
	- [Executive Report](#executive-report)

# Revenue, Cost, and Profit
Profit is one of the first things people use to assess a company's success. In this chapter, you'll learn how to calculate revenue and cost, and then combine the two calculations using Common Table Expressions to calculate profit.

## Profit per Eatery
- Analyzes profitability at the restaurant or store level.
- Helps management identify which eateries perform best financially and informs decisions on resource allocation or operational improvements.
```sql
WITH revenue AS (
  -- Calculate revenue per eatery
  SELECT meals.eatery,
         SUM(orders.order_quantity * meals.meal_price) AS revenue
    FROM meals
    JOIN orders ON meals.meal_id = orders.meal_id
   GROUP BY eatery),

  cost AS (
  -- Calculate cost per eatery
  SELECT meals.eatery,
         SUM(stock.stocked_quantity * meals.meal_cost) AS cost
    FROM meals
    JOIN stock ON meals.meal_id = stock.meal_id
   GROUP BY eatery)

   -- Calculate profit per eatery
   SELECT revenue.eatery,
          SUM(revenue - cost) AS profit
     FROM revenue
     JOIN cost ON revenue.eatery = cost.eatery
     GROUP BY revenue.eatery
    ORDER BY profit DESC;
```
## Profit per Month
```sql
-- Set up the revenue CTE
WITH revenue AS ( 
	SELECT
		DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
		SUM(orders.order_quantity * meals.meal_price) AS revenue
	FROM meals
	JOIN orders ON meals.meal_id = orders.meal_id
	GROUP BY delivr_month),
-- Set up the cost CTE
  cost AS (
 	SELECT
		DATE_TRUNC('month', stocking_date) :: DATE AS delivr_month,
		SUM(stock.stocked_quantity * meals.meal_cost) AS cost
	FROM meals
    JOIN stock ON meals.meal_id = stock.meal_id
	GROUP BY delivr_month)
-- Calculate profit by joining the CTEs
SELECT
	revenue.delivr_month,
	revenue - cost AS profit
FROM revenue
JOIN cost ON revenue.delivr_month = cost.delivr_month
ORDER BY revenue.delivr_month ASC;
```
# User-Centric KPIs
Financial KPIs like profit are important, but they don't speak to user activity and engagement. In this chapter, you'll learn how to calculate the registrations and active users KPIs, and use window functions to calculate the user growth and retention rates.

## Retention Rate
- Measures the percentage of customers who return to make additional purchases over time.
- Critical for evaluating customer satisfaction and the effectiveness of customer retention initiatives.
```sql
WITH user_monthly_activity AS (
  SELECT DISTINCT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    user_id
  FROM orders)

SELECT
  -- Calculate the MoM retention rates
  previous.delivr_month,
  ROUND(
    COUNT(DISTINCT current.user_id) :: NUMERIC/    GREATEST(COUNT(DISTINCT previous.user_id), 1),
  2) AS retention_rate
FROM user_monthly_activity AS previous
LEFT JOIN user_monthly_activity AS current
-- Fill in the user and month join conditions
ON previous.user_id = current.user_id
AND previous.delivr_month = (current.delivr_month -INTERVAL'1 month')
GROUP BY previous.delivr_month
ORDER BY previous.delivr_month ASC;
```

# ARPU, Histograms, and Percentiles
Since a KPI is a single number, it can't describe how data is distributed. In this chapter, you'll learn about unit economics, histograms, bucketing, and percentiles, which you can use to spot the variance in user behaviors.

## Bucketing Users by Revenue/Orders
- Segments users into different groups based on revenue generated or frequency of orders.
- Supports precision marketing by helping identify high-value customers, occasional users, or inactive segments.
```sql
-- Bucketing Users by Revenue
WITH user_revenues AS (
  SELECT
    -- Select the user IDs and the revenues they generate
    o.user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  -- Fill in the bucketing conditions
  CASE
    WHEN revenue < 150 THEN 'Low-revenue users'
    WHEN revenue < 300 THEN 'Mid-revenue users'
    ELSE 'High-revenue users'
  END AS revenue_group,
  COUNT(DISTINCT user_id) AS users
FROM user_revenues
GROUP BY revenue_group;

-- Bucketing Users by Orders
-- Store each user's count of orders in a CTE named user_orders
WITH user_orders AS (
  SELECT
    user_id,
    COUNT(DISTINCT order_id) AS orders
  FROM orders
  GROUP BY user_id)

SELECT
  -- Write the conditions for the three buckets
  CASE
    WHEN orders < 8 THEN 'Low-orders users'
    WHEN orders < 15 THEN 'Mid-orders users'
    ELSE 'High-orders users'
  END AS order_group,
  -- Count the distinct users in each bucket
  COUNT(DISTINCT user_id) AS users
FROM user_orders
GROUP BY order_group;
```
## Revenue Quartiles
- Uses quartile-based analysis to understand revenue distribution across customers.
- The interquartile range helps detect outliers, ensuring business decisions are based on representative data rather than extreme values.
```sql
WITH user_revenues AS (
  -- Select the user IDs and their revenues
  SELECT
    o.user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  -- Calculate the first, second, and third quartile
  ROUND(
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC, 2) AS revenue_p25,
  ROUND(
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC, 2) AS revenue_p50,
  ROUND(
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC, 2) AS revenue_p75,
  -- Calculate the average
  ROUND(AVG(revenue) :: NUMERIC, 2) AS avg_revenue
FROM user_revenues;
```
## Interquartile Range
```sql
SELECT
  -- Select user_id and calculate revenue by user
  o.user_id,
  SUM(o.order_quantity * m.meal_price) AS revenue
FROM meals AS m
JOIN orders AS o ON m.meal_id = o.meal_id
GROUP BY o.user_id;
```

# Generating an Executive Report
Executives often use the KPIs you've calculated in the three previous chapters to guide business decisions. In this chapter, you'll package the KPIs you've created into a readable report you can present to managers and executives.
## Rank Users by Their Count of Orders
- Ranks customers based on the frequency of their orders.
- Useful for prioritizing customer support, loyalty programs, or promotional campaigns aimed at high-frequency customers.
```sql
SELECT
  user_id,
  COUNT(DISTINCT order_id) AS count_orders
FROM orders
-- Only keep orders in August 2018
WHERE order_date >= '2018-08-01' AND order_date <= '2018-08-31'
GROUP BY user_id;
```
## Pivoting User Revenue by Month
- Transforms data to clearly display user-level revenue trends over time.
- Helps identify seasonal variations, user spending patterns, and areas requiring strategic interventions.
```sql
-- Import tablefunc
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM CROSSTAB($$
  SELECT
    user_id,
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    SUM(meal_price * order_quantity) :: FLOAT AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
 WHERE user_id IN (0, 1, 2, 3, 4)
   AND order_date < '2018-09-01'
 GROUP BY user_id, delivr_month
 ORDER BY user_id, delivr_month;
$$)
-- Select user ID and the months from June to August 2018
AS ct (user_id INT,
       "2018-06-01" FLOAT,
       "2018-07-01" FLOAT,
       "2018-08-01" FLOAT)
ORDER BY user_id ASC;
```
## Costs
```sql
SELECT
  -- Select eatery and calculate total cost
  meals.eatery,
  DATE_TRUNC('month', stocking_date) :: DATE AS delivr_month,
  SUM(meals.meal_cost * stock.stocked_quantity) :: FLOAT AS cost
FROM meals
JOIN stock ON meals.meal_id = stock.meal_id
-- Keep only the records after October 2018
WHERE DATE_TRUNC('month', stocking_date) > '2018-10-01'
GROUP BY eatery, delivr_month
ORDER BY eatery, delivr_month;
```
## Executive Report
```sql
SELECT
  eatery,
  -- Format the order date so "2018-06-01" becomes "Q2 2018"
  TO_CHAR(order_date, '"Q"Q YYYY') AS delivr_quarter,
  -- Count unique users
  COUNT(DISTINCT orders.user_id) AS users
FROM meals
JOIN orders ON meals.meal_id = orders.meal_id
GROUP BY eatery, delivr_quarter
ORDER BY delivr_quarter, users;
```
