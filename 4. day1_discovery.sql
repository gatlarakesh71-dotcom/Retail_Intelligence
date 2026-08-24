-- 1) Customers in a specific city
SELECT *
FROM   dbo.bm_customers
WHERE  city = 'Dubai';

-- 2) Sales for a specific store
SELECT *
FROM   dbo.bm_sales
WHERE  store_id = 1;

-- 3) Inventory with low stock
SELECT *
FROM   dbo.bm_inventory
WHERE  stock_on_hand < 20;

-------------------------------------------------------------------------
-- INNER JOIN queries (2 tables)
-- 1) Sales with store details
SELECT s.date,
       s.store_id,
       st.store_name,
       st.city,
       s.total_value
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_stores AS st
       ON s.store_id = st.store_id;

-- 2) Sales with product details
SELECT s.date,
       s.sku_id,
       sk.sku_name,
       sk.category,
       s.quantity,
       s.total_value
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_skus AS sk
       ON s.sku_id = sk.sku_id;

-- 3) Inventory with product details
SELECT i.store_id,
       i.sku_id,
       sk.sku_name,
       sk.category,
       i.stock_on_hand,
       i.reorder_point
FROM   dbo.bm_inventory AS i
       INNER JOIN
       dbo.bm_skus AS sk
       ON i.sku_id = sk.sku_id;

---------------------------------------------------------------------------
-- JOIN queries with 3 or more tables
-- 1) Sales with store and product details
SELECT s.date,
       st.store_name,
       st.city,
       sk.sku_name,
       sk.category,
       s.quantity,
       s.total_value
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_stores AS st
       ON s.store_id = st.store_id
       INNER JOIN
       dbo.bm_skus AS sk
       ON s.sku_id = sk.sku_id;

-- 2) Sales with customer, store and product details
SELECT s.date,
       c.cust_id,
       c.city AS customer_city,
       c.loyalty_segment,
       st.store_name,
       sk.sku_name,
       sk.category,
       s.quantity,
       s.total_value
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_customers AS c
       ON s.customer_id = c.cust_id
       INNER JOIN
       dbo.bm_stores AS st
       ON s.store_id = st.store_id
       INNER JOIN
       dbo.bm_skus AS sk
       ON s.sku_id = sk.sku_id;

-- 3) Inventory with store and product details
SELECT i.snapshot_date,
       st.store_name,
       st.city,
       sk.sku_name,
       sk.category,
       sk.brand,
       i.stock_on_hand,
       i.reorder_point,
       i.safety_stock
FROM   dbo.bm_inventory AS i
       INNER JOIN
       dbo.bm_stores AS st
       ON i.store_id = st.store_id
       INNER JOIN
       dbo.bm_skus AS sk
       ON i.sku_id = sk.sku_id;

---------------------------------------------------------------------------
-- LEFT JOIN queries
-- 1) All customers, with sales if available
SELECT c.cust_id,
       c.city,
       c.loyalty_segment,
       s.date,
       s.total_value
FROM   dbo.bm_customers AS c
       LEFT OUTER JOIN
       dbo.bm_sales AS s
       ON c.cust_id = s.customer_id;

-- 2) All products, with inventory if available
SELECT sk.sku_id,
       sk.sku_name,
       sk.category,
       i.store_id,
       i.stock_on_hand
FROM   dbo.bm_skus AS sk
       LEFT OUTER JOIN
       dbo.bm_inventory AS i
       ON sk.sku_id = i.sku_id;

-- 3) All stores, with sales if available
SELECT st.store_id,
       st.store_name,
       st.city,
       s.date,
       s.total_value
FROM   dbo.bm_stores AS st
       LEFT OUTER JOIN
       dbo.bm_sales AS s
       ON st.store_id = s.store_id;

---------------------------------------------------------------------------
-- TOP records with ORDER BY
-- 1) Top 10 sales by total value
SELECT TOP 10
       *
FROM   dbo.bm_sales
ORDER BY total_value DESC;

-- 2) Top 5 stores by total sales
SELECT TOP 5
       s.store_id,
       st.store_name,
       SUM(s.total_value) AS total_sales
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_stores AS st
       ON s.store_id = st.store_id
GROUP BY s.store_id,
         st.store_name
ORDER BY total_sales DESC;

-- 3) Top 10 products by total quantity sold
SELECT TOP 10
       sk.sku_id,
       sk.sku_name,
       SUM(s.quantity) AS total_quantity_sold
FROM   dbo.bm_sales AS s
       INNER JOIN
       dbo.bm_skus AS sk
       ON s.sku_id = sk.sku_id
GROUP BY sk.sku_id,
         sk.sku_name
ORDER BY total_quantity_sold DESC;