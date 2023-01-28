-- Danny's Dinner Case Study

-- Codes to create the schema and tables

CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

  Questions
-- 1 What is the total amount each customer spent at the restaurant?
  -- Relevant table: Sales (contains the customer_id) and menu (contains the price).
  -- Both tables have product_id. Let's explore this to determine an appropriate join type

WITH sales_distribution AS (
  SELECT
    product_id,
    COUNT(*) AS row_count
  FROM dannys_diner.sales
  GROUP BY product_id
)
SELECT
  row_count,
  COUNT(product_id) AS product_id_count
FROM sales_distribution
GROUP BY row_count;
    
    -- Each unique product_id appears more than once in the sales table (one to many relationship)
    
WITH menu_distribution AS (
  SELECT
    product_id,
    COUNT(*) AS row_count
  FROM dannys_diner.menu
  GROUP BY product_id
)
SELECT
  row_count,
  COUNT(product_id) AS product_id_count
FROM menu_distribution
GROUP BY row_count;

    -- Each unique product_id appears only once in the menu table (one to one relationship)
    -- Is there a unique product_id in the sales table that is not in the menu table?
    
SELECT
  COUNT(DISTINCT product_id)
FROM dannys_diner.sales
WHERE NOT EXISTS (
  SELECT
    product_id
  FROM dannys_diner.menu
);
    -- There is no unique product_id in the menu table that does not exist in the sales table
    -- What about the other way round?
    
SELECT
  COUNT(DISTINCT product_id)
FROM dannys_diner.menu
WHERE NOT EXISTS (
  SELECT
    product_id
  FROM dannys_diner.sales
);
    -- There is als no unique product_id in the sales table that does not exist in the menu table
    -- Considering all these findings, the best join type here is an inner join
    
SELECT
  sales.customer_id AS customer,
  SUM(menu.price) AS total_spent
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY SUM(menu.price) DESC;

-- 2 How many days has each customer visited the restaurant?
-- This is simply counting the number of unique (DISTINCT) days a customer has purchased an item from the restaurant
-- This is gotten easily from the sales table

SELECT
  customer_id,
  COUNT(DISTINCT order_date) AS days
FROM dannys_diner.sales
GROUP BY customer_id;

-- 3 What was the first item from the menu purchased by each customer?
-- Again, the relevant tables here are the sales (contains customer_id) and menu (contains product_name) tables
-- We have already established that an inner join on product_id is appropriate here

SELECT
  *
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
LIMIT 5;

-- We have to find a way to rank the order_date for earliest (smallest) to latest (highest)
-- RANK or DENSE_RANK would be required here
-- What should be done about products purchased on the same day?
-- With no explicit instruction, it is better to retrieve all products purchased by a customer on the same day as the first 
  --provided that date is the first time the customer is purchasing an item

WITH joined_data AS (  
  SELECT
    sales.customer_id,
    menu.product_name,
    sales.order_date,
    RANK() OVER (
      PARTITION BY sales.customer_id
      ORDER BY order_date
    ) AS rank_number
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
)
SELECT DISTINCT
  customer_id,
  product_name
FROM joined_data
WHERE rank_number = 1;

-- 4 What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Again, the information we need is in our sales and menu table so we can inner join again.

SELECT
  *
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
LIMIT 5;

-- Here, we need to count how many times a product appears in the dataset and take maximum number as the most purchased item

SELECT
  menu.product_name,
  COUNT(*) AS frequency
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id 
GROUP BY menu.product_name
ORDER BY COUNT(*) DESC
LIMIT 1;

-- 5 Which item was the most popular for each customer?
-- The sales and menu tables are needed again and can perform an inner join once more
-- Calculations should be made per customer_id first and then per product_name

WITH popularity AS (
  SELECT DISTINCT
    sales.customer_id,
    menu.product_name,
    COUNT(*) AS frequency
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
  GROUP BY sales.customer_id,
    menu.product_name
  -- The generated counts (frequency) can now be ranked per customer_id
), popularity_rank AS (
  SELECT
    customer_id,
    product_name,
    frequency,
    RANK() OVER (
      PARTITION BY customer_id
      ORDER BY frequency DESC
    ) AS rank_number
  FROM popularity
  -- The most popular item for each customer will be the one with a rank_number of 1
)
SELECT DISTINCT
  customer_id,
  product_name,
  frequency
FROM popularity_rank
WHERE rank_number = 1;

-- 6 Which item was purchased first by the customer after they became a member?
-- The members table contains the unique customer_id (one to one relationship) and the join_date
-- Hence, the three tables need to be inner joined for this exercise

-- Use a cte to retrieve the desired table
WITH purchase_order AS (
  SELECT DISTINCT
  -- retrieve relevant columns
    members.customer_id,
    menu.product_name,
    members.join_date,
    sales.order_date,
  -- rank by order_date per customer_id
    RANK() OVER (
      PARTITION BY members.customer_id
      ORDER BY sales.order_date
    ) AS rank_number
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
  INNER JOIN dannys_diner.members
  ON sales.customer_id = members.customer_id
  -- This table can now be filtered to retrieve only rows where order_date is later (greater) than or equal to (same day) the join_date
  WHERE sales.order_date >= members.join_date
)
SELECT 
  customer_id,
  product_name,
  join_date,
  order_date
FROM purchase_order
-- the first purchased item will have a rank_number of 1
WHERE rank_number = 1;

-- 7 Which item was purchased just before the customer became a member?
-- This is just like question 6 but in the reverse order

-- Use a cte to retrieve the desired table
WITH purchase_order AS (
  SELECT DISTINCT
  -- retrieve relevant columns
    members.customer_id,
    menu.product_name,
    members.join_date,
    sales.order_date,
  -- rank by order_date per customer_id
    RANK() OVER (
      PARTITION BY members.customer_id
      ORDER BY sales.order_date DESC 
      -- The order is descending here because we want the date closest to the join_date but before it
    ) AS rank_number
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
  INNER JOIN dannys_diner.members
  ON sales.customer_id = members.customer_id
  -- This table can now be filtered to retrieve only rows where order_date is earlier (less) than the join_date
  WHERE sales.order_date < members.join_date
)
SELECT 
  customer_id,
  product_name,
  join_date,
  order_date
FROM purchase_order
-- the first purchased item will have a rank_number of 1
WHERE rank_number = 1;

-- 8 What is the total number of items and amount spent for each member before they became a member?
-- All three tables are needed to answer this question and we can perform an inner join as always

SELECT
  members.customer_id,
  COUNT(menu.product_name) AS unique_items,
  SUM(menu.price) AS amount_spent
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
INNER JOIN dannys_diner.members
ON sales.customer_id = members.customer_id
-- This table is filtered to retrieve only rows where order_date is earlier (less) than the join_date
WHERE sales.order_date < members.join_date 
GROUP BY members.customer_id
ORDER BY members.customer_id;

-- 9 If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- Only the sales and menu tables are needed here since there is no need to filter by join_date

SELECT
  sales.customer_id,
  SUM(
    -- Use case-when statements to make the desired calculations
    CASE
      WHEN product_name = 'sushi' THEN menu.price * 20
      ELSE menu.price * 10
    END
  ) AS points
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 10 In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi 
-- how many points do customer A and B have at the end of January?
-- We need all three tables for this exercise again because of the join_date

SELECT
  members.customer_id,
  -- Determine the next 7 days after the join_date for each member
  SUM(
    CASE
      WHEN sales.order_date::DATE BETWEEN (members.join_date::DATE) AND (members.join_date::DATE+6) THEN menu.price * 20
      WHEN product_name = 'sushi' THEN menu.price * 20
      ELSE menu.price * 10
    END
  ) AS points
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
INNER JOIN dannys_diner.members
ON sales.customer_id = members.customer_id
WHERE sales.order_date <= '2021-01-31'
GROUP BY members.customer_id;


-- Bonus
-- Create a table for Danny that shows if a customer was a member or not when a purchase was made
-- All three tables are needed for this too as well as case-when statements
-- However, left join should be used to capture details of customers who may not be in the members table
SELECT
  sales.customer_id,
  sales.order_date,
  menu.product_name,
  menu.price,
  CASE
    WHEN sales.order_date >= members.join_date THEN 'Y'
    ELSE 'N'
  END AS _member
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
LEFT JOIN dannys_diner.members
ON sales.customer_id = members.customer_id
ORDER BY members.customer_id, sales.order_date;

-- Danny also requires further information about the ranking of customer products by order_date. 
-- However, he purposely does not need the ranking for non-member purchases.
-- So, he expects null ranking values for the records when customers are not yet part of the loyalty program.
-- DENSE_RANK will be useful here to account for ties.
-- case-when can be used to specify rows on which the function should run based on whether the customer is a member or not
-- A cte will also be needed for this to make the code clear and easy to create_date

WITH product_ranking AS (
  SELECT
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
    CASE
      WHEN sales.order_date >= members.join_date THEN 'Y'
      ELSE 'N'
    END AS _member,
    DENSE_RANK() OVER (
      PARTITION BY sales.customer_id
      ORDER BY CASE 
        WHEN sales.order_date >= members.join_date THEN sales.order_date
        ELSE NULL
      END
    ) AS product_rank
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
  LEFT JOIN dannys_diner.members
  ON sales.customer_id = members.customer_id
)
SELECT
  customer_id,
  order_date,
  product_name,
  price,
  _member,
  CASE
    WHEN _member = 'Y' THEN product_rank
    ELSE NULL
  END AS product_rank
FROM product_ranking
ORDER BY customer_id, order_date;