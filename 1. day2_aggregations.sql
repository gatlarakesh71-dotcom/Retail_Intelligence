-- 1. Revenue by region and store type
SELECT   st.city AS region,
         st.store_type,
         SUM(s.total_value) AS revenue,
         SUM(s.quantity) AS units_sold,
         COUNT(*) AS sales_transactions
FROM     dbo.bm_sales AS s
         INNER JOIN
         dbo.bm_stores AS st
         ON s.store_id = st.store_id
GROUP BY st.city, st.store_type
ORDER BY revenue DESC;

-- 2. Top 5 product categories by revenue
SELECT   TOP 5 sk.category,
               SUM(s.total_value) AS revenue,
               SUM(s.quantity) AS units_sold,
               COUNT(*) AS transactions
FROM     dbo.bm_sales AS s
         INNER JOIN
         dbo.bm_skus AS sk
         ON s.sku_id = sk.sku_id
GROUP BY sk.category
ORDER BY revenue DESC;

-- 3. Customer spend tiers (High, Medium, Low)
WITH     customer_spend
AS       (SELECT   c.cust_id,
                   c.city,
                   COALESCE (SUM(CAST (s.total_value AS DECIMAL (18, 2))), 0) AS total_spend
          FROM     dbo.bm_customers AS c
                   LEFT OUTER JOIN
                   dbo.bm_sales AS s
                   ON TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) = c.cust_id
          GROUP BY c.cust_id, c.city)
SELECT   cust_id,
         city,
         total_spend,
         CASE WHEN total_spend >= 15001 THEN 'High' WHEN total_spend BETWEEN 5001 AND 15000 THEN 'Medium' ELSE 'Low' END AS spend_tier
FROM     customer_spend
ORDER BY total_spend DESC;

-- 4. Check if promotions increased sales
WITH     promo_flagged
AS       (SELECT s.date,
                 s.total_value,
                 s.quantity,
                 CASE WHEN p.promo_id IS NOT NULL THEN 1 ELSE 0 END AS is_promo
          FROM   dbo.bm_sales AS s
                 LEFT OUTER JOIN
                 dbo.bm_promotions AS p
                 ON s.date BETWEEN CAST (p.start_date AS DATE) AND CAST (p.end_date AS DATE))
SELECT   CASE WHEN is_promo = 1 THEN 'Promotion Period' ELSE 'Non-Promotion Period' END AS sales_period,
         COUNT(*) AS transactions,
         SUM(quantity) AS units_sold,
         SUM(total_value) AS revenue,
         AVG(total_value) AS avg_revenue_per_transaction
FROM     promo_flagged
GROUP BY is_promo
ORDER BY is_promo DESC;

-- uplift version
WITH   promo_flagged
AS     (SELECT s.date,
               s.total_value,
               s.quantity,
               CASE WHEN p.promo_id IS NOT NULL THEN 1 ELSE 0 END AS is_promo
        FROM   dbo.bm_sales AS s
               LEFT OUTER JOIN
               dbo.bm_promotions AS p
               ON s.date BETWEEN CAST (p.start_date AS DATE) AND CAST (p.end_date AS DATE))
SELECT SUM(CASE WHEN is_promo = 1 THEN total_value ELSE 0 END) AS promo_revenue,
       SUM(CASE WHEN is_promo = 0 THEN total_value ELSE 0 END) AS non_promo_revenue,
       SUM(CASE WHEN is_promo = 1 THEN total_value ELSE 0 END) - SUM(CASE WHEN is_promo = 0 THEN total_value ELSE 0 END) AS revenue_delta,
       CAST (100.0 * (SUM(CASE WHEN is_promo = 1 THEN total_value ELSE 0 END) - SUM(CASE WHEN is_promo = 0 THEN total_value ELSE 0 END)) / NULLIF (SUM(CASE WHEN is_promo = 0 THEN total_value ELSE 0 END), 0) AS DECIMAL (10, 2)) AS promo_vs_nonpromo_pct_change
FROM   promo_flagged;

-- 5. Customers who spend above average
WITH     customer_spend
AS       (SELECT   c.cust_id,
                   c.city,
                   COALESCE (SUM(CAST (s.total_value AS DECIMAL (18, 2))), 0) AS total_spend
          FROM     dbo.bm_customers AS c
                   LEFT OUTER JOIN
                   dbo.bm_sales AS s
                   ON TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) = c.cust_id
          GROUP BY c.cust_id, c.city),
         avg_spend
AS       (SELECT AVG(total_spend) AS avg_customer_spend
          FROM   customer_spend)
SELECT   cs.cust_id,
         cs.city,
         cs.total_spend,
         avg.avg_customer_spend
FROM     customer_spend AS cs CROSS JOIN avg_spend AS avg
WHERE    cs.total_spend > avg.avg_customer_spend
ORDER BY cs.total_spend DESC;

-- 6. Products with falling sales month over month
WITH     monthly_sku_sales
AS       (SELECT   DATEFROMPARTS(YEAR(s.date), MONTH(s.date), 1) AS sales_month,
                   sk.sku_id,
                   sk.sku_name,
                   SUM(s.total_value) AS monthly_revenue,
                   SUM(s.quantity) AS monthly_units
          FROM     dbo.bm_sales AS s
                   INNER JOIN
                   dbo.bm_skus AS sk
                   ON s.sku_id = sk.sku_id
          GROUP BY DATEFROMPARTS(YEAR(s.date), MONTH(s.date), 1), sk.sku_id, sk.sku_name),
         product_mom
AS       (SELECT sales_month,
                 sku_id,
                 sku_name,
                 monthly_revenue,
                 monthly_units,
                 LAG(monthly_revenue) OVER (PARTITION BY sku_id ORDER BY sales_month) AS prev_month_revenue,
                 LAG(monthly_units) OVER (PARTITION BY sku_id ORDER BY sales_month) AS prev_month_units
          FROM   monthly_sku_sales)
SELECT   sku_id,
         sku_name,
         sales_month,
         monthly_revenue,
         prev_month_revenue,
         monthly_revenue - prev_month_revenue AS revenue_change,
         CAST (100.0 * (monthly_revenue - prev_month_revenue) / NULLIF (prev_month_revenue, 0) AS DECIMAL (10, 2)) AS pct_change_revenue,
         monthly_units,
         prev_month_units
FROM     product_mom
WHERE    prev_month_revenue IS NOT NULL
         AND monthly_revenue < prev_month_revenue
ORDER BY pct_change_revenue ASC;

-- 7. Rank stores within each region
WITH     store_revenue
AS       (SELECT   st.city AS region,
                   st.store_id,
                   st.store_name,
                   SUM(s.total_value) AS total_revenue
          FROM     dbo.bm_sales AS s
                   INNER JOIN
                   dbo.bm_stores AS st
                   ON s.store_id = st.store_id
          GROUP BY st.city, st.store_id, st.store_name)
SELECT   region,
         store_id,
         store_name,
         total_revenue,
         RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) AS store_rank_within_region
FROM     store_revenue
ORDER BY region, store_rank_within_region;

--8. Data Quality Check for Retail Intelligence Project
----Purpose: identify nulls, wrong/invalid values
-- 1) Null checks across main tables
SELECT 'bm_customers' AS table_name,
       'cust_id' AS column_name,
       COUNT(*) AS null_count
FROM   dbo.bm_customers
WHERE  cust_id IS NULL
UNION ALL
SELECT 'bm_customers',
       'city',
       COUNT(*)
FROM   dbo.bm_customers
WHERE  city IS NULL
UNION ALL
SELECT 'bm_customers',
       'loyalty_segment',
       COUNT(*)
FROM   dbo.bm_customers
WHERE  loyalty_segment IS NULL
UNION ALL
SELECT 'bm_stores',
       'store_id',
       COUNT(*)
FROM   dbo.bm_stores
WHERE  store_id IS NULL
UNION ALL
SELECT 'bm_stores',
       'city',
       COUNT(*)
FROM   dbo.bm_stores
WHERE  city IS NULL
UNION ALL
SELECT 'bm_skus',
       'sku_id',
       COUNT(*)
FROM   dbo.bm_skus
WHERE  sku_id IS NULL
UNION ALL
SELECT 'bm_skus',
       'sku_name',
       COUNT(*)
FROM   dbo.bm_skus
WHERE  sku_name IS NULL
UNION ALL
SELECT 'bm_sales',
       'date',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  date IS NULL
UNION ALL
SELECT 'bm_sales',
       'customer_id',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  customer_id IS NULL
UNION ALL
SELECT 'bm_sales',
       'store_id',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  store_id IS NULL
UNION ALL
SELECT 'bm_sales',
       'sku_id',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  sku_id IS NULL
UNION ALL
SELECT 'bm_inventory',
       'store_id',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  store_id IS NULL
UNION ALL
SELECT 'bm_inventory',
       'sku_id',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  sku_id IS NULL
UNION ALL
SELECT 'bm_inventory',
       'stock_on_hand',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  stock_on_hand IS NULL
UNION ALL
SELECT 'bm_promotions',
       'promo_id',
       COUNT(*)
FROM   dbo.bm_promotions
WHERE  promo_id IS NULL
UNION ALL
SELECT 'bm_promotions',
       'start_date',
       COUNT(*)
FROM   dbo.bm_promotions
WHERE  start_date IS NULL
UNION ALL
SELECT 'bm_promotions',
       'end_date',
       COUNT(*)
FROM   dbo.bm_promotions
WHERE  end_date IS NULL;

-- 2) Wrong data / invalid value checks
SELECT 'bm_sales' AS table_name,
       'negative_quantity' AS issue,
       COUNT(*) AS issue_count
FROM   dbo.bm_sales
WHERE  quantity < 0
UNION ALL
SELECT 'bm_sales',
       'zero_or_negative_unit_price',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  unit_price <= 0
UNION ALL
SELECT 'bm_sales',
       'zero_or_negative_total_value',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  total_value <= 0
UNION ALL
SELECT 'bm_sales',
       'future_date',
       COUNT(*)
FROM   dbo.bm_sales
WHERE  date > CAST (GETDATE() AS DATE)
UNION ALL
SELECT 'bm_inventory',
       'negative_stock',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  stock_on_hand < 0
UNION ALL
SELECT 'bm_inventory',
       'negative_reorder_point',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  reorder_point < 0
UNION ALL
SELECT 'bm_inventory',
       'negative_safety_stock',
       COUNT(*)
FROM   dbo.bm_inventory
WHERE  safety_stock < 0
UNION ALL
SELECT 'bm_customers',
       'invalid_age',
       COUNT(*)
FROM   dbo.bm_customers
WHERE  age < 0
       OR age > 120
UNION ALL
SELECT 'bm_promotions',
       'end_before_start',
       COUNT(*)
FROM   dbo.bm_promotions
WHERE  end_date < start_date
UNION ALL
SELECT 'bm_promotions',
       'invalid_discount',
       COUNT(*)
FROM   dbo.bm_promotions
WHERE  discount_pct < 0
       OR discount_pct > 100;

-- 9. Repeat purchase rate
WITH   customer_purchase_counts
AS     (SELECT   TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) AS customer_id,
                 COUNT(DISTINCT s.date) AS purchase_count
        FROM     dbo.bm_sales AS s
        GROUP BY TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id))),
       repeat_customers
AS     (SELECT COUNT(*) AS repeat_customer_count
        FROM   customer_purchase_counts
        WHERE  purchase_count > 1),
       total_customers
AS     (SELECT COUNT(*) AS total_customer_count
        FROM   (SELECT DISTINCT TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) AS customer_id
                FROM   dbo.bm_sales AS s) AS x)
SELECT rc.repeat_customer_count,
       tc.total_customer_count,
       CAST (100.0 * rc.repeat_customer_count / NULLIF (tc.total_customer_count, 0) AS DECIMAL (10, 2)) AS repeat_purchase_rate_pct
FROM   repeat_customers AS rc CROSS JOIN total_customers AS tc;

-- 10. Category mix for each region
WITH     region_category_sales
AS       (SELECT   st.city AS region,
                   sk.category,
                   SUM(s.total_value) AS category_revenue,
                   SUM(s.quantity) AS category_units
          FROM     dbo.bm_sales AS s
                   INNER JOIN
                   dbo.bm_stores AS st
                   ON s.store_id = st.store_id
                   INNER JOIN
                   dbo.bm_skus AS sk
                   ON s.sku_id = sk.sku_id
          GROUP BY st.city, sk.category),
         region_totals
AS       (SELECT   region,
                   SUM(category_revenue) AS total_region_revenue
          FROM     region_category_sales
          GROUP BY region)
SELECT   rcs.region,
         rcs.category,
         rcs.category_revenue,
         rcs.category_units,
         CAST (100.0 * rcs.category_revenue / NULLIF (rt.total_region_revenue, 0) AS DECIMAL (10, 2)) AS category_share_pct
FROM     region_category_sales AS rcs
         INNER JOIN
         region_totals AS rt
         ON rcs.region = rt.region
ORDER BY rcs.region, category_share_pct DESC;