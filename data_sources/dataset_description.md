# 📂 Dataset Description

The dataset consists of three tables related to a restaurant business's sales, orders, and inventory.

## Meals Table (`meals`)
- `meal_id` (INT): Unique identifier for each meal.
- `eatery` (TEXT): Name of the restaurant or branch.
- `meal_price` (FLOAT): Price at which the meal is sold.
- `meal_cost` (FLOAT): Cost of ingredients and preparation per meal.

## Orders Table (`orders`)
- `order_date` (DATE): Date when the order was placed.
- `user_id` (INT): Identifier of the user placing the order.
- `order_id` (INT): Identifier of each unique order.
- `meal_id` (INT): Meal ID linking to the meals table.
- `order_quantity` (INT): Number of meals ordered.

## Stock Table (`stock`)
- `stocking_date` (DATE): Date when inventory was replenished.
- `meal_id` (INT): Meal ID referencing the meals table.
- `stocked_quantity` (INT): Number of meals restocked.

**Data Source**: [DataCamp](https://app.datacamp.com/learn/courses/analyzing-business-data-in-sql)  
(See `data_import.sql` for details on importing the data.)
