
# Revenue, Cost, and Profit
Profit is one of the first things people use to assess a company's success. In this chapter, you'll learn how to calculate revenue and cost, and then combine the two calculations using Common Table Expressions to calculate profit.
## Revenue per Customer
```sql  -- Calculate revenue
SELECT SUM(meals.meal_price * orders.order_quantity) AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
-- Keep only the records of customer ID 15
WHERE orders.user_id = 15;
```
## Revenue per Week
```sql
SELECT DATE_TRUNC('week', order_date) :: DATE AS delivr_week,
       -- Calculate revenue
       SUM(meals.meal_price * orders.order_quantity) AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
-- Keep only the records in June 2018
WHERE orders.order_date >= '2018-06-01' AND orders.order_date < '2018-07-01'
GROUP BY delivr_week
ORDER BY delivr_week ASC;
```
## Top Meals by Cost
```sql
SELECT
  -- Calculate cost per meal ID
  meals.meal_id,
  SUM(meals.meal_cost * stock.stocked_quantity) AS cost
FROM meals
JOIN stock ON meals.meal_id = stock.meal_id
GROUP BY meals.meal_id
ORDER BY cost DESC
-- Only the top 5 meal IDs by purchase cost
LIMIT 5;
```
## Using CTEs
```sql
SELECT
  -- Calculate cost
  DATE_TRUNC('month', stocking_date)::DATE AS delivr_month,
  SUM(stock.stocked_quantity * meals.meal_cost) AS cost
FROM meals
JOIN stock ON meals.meal_id = stock.meal_id
GROUP BY delivr_month
ORDER BY delivr_month ASC;
```
## Profit per Eatery
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
## Registration by Month
```sql
SELECT
  -- Get the earliest (minimum) order date by user ID
  user_id,
  MIN(order_date) AS reg_date
FROM orders
GROUP BY user_id
-- Order by user ID
ORDER BY user_id ASC;
```
## Monthly Active Users(MAU)
```sql
SELECT
  -- Truncate the order date to the nearest month
  DATE_TRUNC('month', orders.order_date) :: DATE AS delivr_month,
  -- Count the unique user IDs
  COUNT(DISTINCT user_id) AS mau
FROM orders
GROUP BY delivr_month
-- Order by month
ORDER BY delivr_month ASC;
```
## Registration Running Total
```sql
WITH reg_dates AS (
  SELECT
    user_id,
    MIN(order_date) AS reg_date
  FROM orders
  GROUP BY user_id)

SELECT
  -- Select the month and the registrations
  DATE_TRUNC('month', reg_date) :: DATE AS delivr_month,
  COUNT(DISTINCT user_id) AS regs
FROM reg_dates
GROUP BY delivr_month
-- Order by month in ascending order
ORDER BY delivr_month ASC;
```
## MAU Monitor
```sql
WITH mau AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS mau
  FROM orders
  GROUP BY delivr_month)

SELECT
  -- Select the month and the MAU
  delivr_month,
  mau,
  COALESCE(
    LAG(mau) OVER (ORDER BY delivr_month ASC),
  0) AS last_mau
FROM mau

-- write a query that returns a table of months and the deltas of each month's current and previous MAUs.
-- If the delta is negative, less users were active in the current month than in the previous month,
-- which triggers the monitor to raise a red flag so the Product team can investigate.
SELECT
  -- Calculate each month's delta of MAUs
  delivr_month, 
  mau - last_mau AS mau_delta
FROM mau_with_lag
-- Order by month in ascending order
ORDER BY delivr_month ASC;

--  Use the month-on-month (MoM) MAU growth rate over a raw delta of MAUs,
-- so that the MAU monitor can have more complex triggers,
-- like raising a yellow flag if the growth rate is -2% and a red flag if the growth rate is -5%.
SELECT
  -- Calculate the MoM MAU growth rates
  delivr_month,
  ROUND(
    (mau - last_mau) :: NUMERIC/ last_mau,
  2) AS growth
FROM mau_with_lag
-- Order by month in ascending order
ORDER BY delivr_month;
```
## Order Growth Rate
```sql
WITH orders AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    --  Count the unique order IDs
    COUNT(DISTINCT order_id) AS orders
  FROM orders
  GROUP BY delivr_month),

  orders_with_lag AS (
  SELECT
    delivr_month,
    -- Fetch each month's current and previous orders
    orders,
    COALESCE(
      LAG(orders) OVER (ORDER BY delivr_month ASC),
    1) AS last_orders
  FROM orders)

SELECT
  delivr_month,
  -- Calculate the MoM order growth rate
  ROUND(
    (orders - last_orders) :: NUMERIC/ last_orders,
  2) AS growth
FROM orders_with_lag
ORDER BY delivr_month ASC;
```
## Retention Rate
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
## Average Revenue per User
```sql
SELECT
  -- Select the user ID and calculate revenue
  user_id,
  SUM(m.meal_price * o.order_quantity) AS revenue
FROM meals AS m
JOIN orders AS o ON m.meal_id = o.meal_id
GROUP BY user_id;
```
## ARPU per Week
```sql
WITH kpi AS (
  SELECT
    -- Select the week, revenue, and count of users
    DATE_TRUNC('week', order_date) :: DATE AS delivr_week,
    SUM(o.order_quantity * m.meal_price) AS revenue,
    COUNT(DISTINCT user_id) AS users
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY delivr_week)

SELECT
  delivr_week,
  -- Calculate ARPU
  ROUND(revenue :: NUMERIC/ GREATEST(users, 1),
  2) AS arpu
FROM kpi
-- Order by week in ascending order
ORDER BY delivr_week ASC;
```
## Average Orders per User
```sql
WITH kpi AS (
  SELECT
    -- Select the count of orders and users
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT user_id) AS users
  FROM orders)

SELECT
  -- Calculate the average orders per user
  ROUND( orders :: NUMERIC/ GREATEST(users, 1),
  2) AS arpu
FROM kpi;
```
## Histogram of Revenue
```sql
WITH user_revenues AS (
  SELECT
    -- Select the user ID and revenue
    user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  -- Return the frequency table of revenues by user
  ROUND(revenue :: NUMERIC, -2) AS revenue_100,
  COUNT(DISTINCT user_id) AS users
FROM user_revenues
GROUP BY revenue_100
ORDER BY revenue_100 ASC;
```
## Histogram of Orders
```sql
SELECT
  -- Select the user ID and the count of orders
  user_id,
  COUNT(DISTINCT order_id) AS orders
FROM orders
GROUP BY user_id
ORDER BY user_id ASC
LIMIT 5;
```
## Bucketing Users by Orders
```sql
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
```
## Bucketing Users by Orders
```sql
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
## Formatting Dates
```sql
SELECT DISTINCT
  -- Select the order date
  order_date,
  -- Format the order date
  TO_CHAR(order_date, 'FMDay DD, FMMonth YYYY') AS format_order_date
FROM orders
ORDER BY order_date ASC
LIMIT 3;
```
## Rank Users by Their Count of Orders
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
