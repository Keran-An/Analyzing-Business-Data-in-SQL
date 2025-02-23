# Introduction to Exploratory Data Analysis (EDA)
The goal of EDA is to quickly understand, summarize, and visualize the fundamental characteristics and patterns within our dataset.

By using SQL to perform EDA, we'll gain insights into the data’s structure, distributions, trends, and basic metrics. This sets the foundation for deeper analysis and effective decision-making.

# Table of Contents
- [Revenue, Cost, and Profit](#revenue-cost-and-profit)
	- [Revenue per Week](#revenue-per-week)
	- [Top Meals by Cost](#top-meals-by-cost)
- [User-Centric KPIs](#user-centric-kpis)
	- [Registration by Month](#registration-by-month)
	- [Monthly Active Users(MAU)](#monthly-active-users-mau)
		- [MAU Monitor](#mau-monitor)
	- [Order Growth Rate](#order-growth-rate)
- [ARPU, Histograms, and Percentiles](#arpu-histograms-and-percentiles)
	- [Average Revenue per User](#average-revenue-per-user)
	- [Histogram of Revenue](#histogram-of-revenue)
	- [Histogram of Orders](#histogram-of-orders)
	
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
- Examines how revenue changes on a weekly basis.
- Helps identify sales trends, seasonal fluctuations, and peak periods.
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
- Lists meals that have the highest associated costs.
- Assists in identifying cost-intensive products or areas that may need cost optimization.
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
# User-Centric KPIs
Financial KPIs like profit are important, but they don't speak to user activity and engagement. In this chapter, you'll learn how to calculate the registrations and active users KPIs, and use window functions to calculate the user growth and retention rates.
## Registration by Month
- Tracks the number of new user registrations per month.
- Important for understanding customer acquisition trends over time.
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
- Measures the number of unique users active in a given month.
- Essential for tracking user engagement and retention over time.
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
### MAU Monitor
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
- Monitors the percentage change in the number of orders between time periods.
- Highlights business growth patterns or potential declines.
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
- Visualizes how revenue amounts are distributed across orders or customers.
- Useful for quickly identifying typical revenue sizes and spotting outliers.
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
- Illustrates the frequency distribution of orders.
- Helps understand how frequently customers purchase or how order volumes vary.
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
