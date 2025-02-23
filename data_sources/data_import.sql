DROP TABLE IF EXISTS "meals";
CREATE TABLE meals (
  meal_id INT,
  eatery TEXT,
  meal_price FLOAT,
  meal_cost FLOAT
);

DROP TABLE IF EXISTS "orders";
CREATE TABLE orders (
  order_date DATE,
  user_id INT,
  order_id INT,
  meal_id INT,
  order_quantity INT
);

DROP TABLE IF EXISTS "stock";
CREATE TABLE stock (
  stocking_date DATE,
  meal_id INT,
  stocked_quantity INT
);

COPY meals
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/732c094b30a2e794d0b12b12547587a903126f68/meals.csv"' (DELIMITER ',', FORMAT CSV);

COPY orders
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/606e6e9165c25477db078996fa7e0a3e994b93d3/orders.csv"' (DELIMITER ',', FORMAT CSV);

COPY stock
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/10d9ad146a85010d836cfc93870aa464951f0640/stock.csv"' (DELIMITER ',', FORMAT CSV);
