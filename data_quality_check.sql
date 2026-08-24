-- Data Quality Check for Retail Intelligence Project
-- Purpose: identify nulls, invalid values, duplicates, and suspicious records

-- 1) Null checks across main tables
SELECT
    'bm_customers' AS table_name,
    'cust_id' AS column_name,
    COUNT(*) AS null_count
FROM dbo.bm_customers
WHERE cust_id IS NULL

UNION ALL
SELECT
    'bm_customers',
    'city',
    COUNT(*)
FROM dbo.bm_customers
WHERE city IS NULL

UNION ALL
SELECT
    'bm_customers',
    'loyalty_segment',
    COUNT(*)
FROM dbo.bm_customers
WHERE loyalty_segment IS NULL

UNION ALL
SELECT
    'bm_stores',
    'store_id',
    COUNT(*)
FROM dbo.bm_stores
WHERE store_id IS NULL

UNION ALL
SELECT
    'bm_stores',
    'city',
    COUNT(*)
FROM dbo.bm_stores
WHERE city IS NULL

UNION ALL
SELECT
    'bm_skus',
    'sku_id',
    COUNT(*)
FROM dbo.bm_skus
WHERE sku_id IS NULL

UNION ALL
SELECT
    'bm_skus',
    'sku_name',
    COUNT(*)
FROM dbo.bm_skus
WHERE sku_name IS NULL

UNION ALL
SELECT
    'bm_sales',
    'date',
    COUNT(*)
FROM dbo.bm_sales
WHERE date IS NULL

UNION ALL
SELECT
    'bm_sales',
    'customer_id',
    COUNT(*)
FROM dbo.bm_sales
WHERE customer_id IS NULL

UNION ALL
SELECT
    'bm_sales',
    'store_id',
    COUNT(*)
FROM dbo.bm_sales
WHERE store_id IS NULL

UNION ALL
SELECT
    'bm_sales',
    'sku_id',
    COUNT(*)
FROM dbo.bm_sales
WHERE sku_id IS NULL

UNION ALL
SELECT
    'bm_inventory',
    'store_id',
    COUNT(*)
FROM dbo.bm_inventory
WHERE store_id IS NULL

UNION ALL
SELECT
    'bm_inventory',
    'sku_id',
    COUNT(*)
FROM dbo.bm_inventory
WHERE sku_id IS NULL

UNION ALL
SELECT
    'bm_inventory',
    'stock_on_hand',
    COUNT(*)
FROM dbo.bm_inventory
WHERE stock_on_hand IS NULL

UNION ALL
SELECT
    'bm_promotions',
    'promo_id',
    COUNT(*)
FROM dbo.bm_promotions
WHERE promo_id IS NULL

UNION ALL
SELECT
    'bm_promotions',
    'start_date',
    COUNT(*)
FROM dbo.bm_promotions
WHERE start_date IS NULL

UNION ALL
SELECT
    'bm_promotions',
    'end_date',
    COUNT(*)
FROM dbo.bm_promotions
WHERE end_date IS NULL;

-- 2) Wrong data / invalid value checks
SELECT
    'bm_sales' AS table_name,
    'negative_quantity' AS issue,
    COUNT(*) AS issue_count
FROM dbo.bm_sales
WHERE quantity < 0

UNION ALL
SELECT
    'bm_sales',
    'zero_or_negative_unit_price',
    COUNT(*)
FROM dbo.bm_sales
WHERE unit_price <= 0

UNION ALL
SELECT
    'bm_sales',
    'zero_or_negative_total_value',
    COUNT(*)
FROM dbo.bm_sales
WHERE total_value <= 0

UNION ALL
SELECT
    'bm_sales',
    'future_date',
    COUNT(*)
FROM dbo.bm_sales
WHERE date > CAST(GETDATE() AS date)

UNION ALL
SELECT
    'bm_inventory',
    'negative_stock',
    COUNT(*)
FROM dbo.bm_inventory
WHERE stock_on_hand < 0

UNION ALL
SELECT
    'bm_inventory',
    'negative_reorder_point',
    COUNT(*)
FROM dbo.bm_inventory
WHERE reorder_point < 0

UNION ALL
SELECT
    'bm_inventory',
    'negative_safety_stock',
    COUNT(*)
FROM dbo.bm_inventory
WHERE safety_stock < 0

UNION ALL
SELECT
    'bm_customers',
    'invalid_age',
    COUNT(*)
FROM dbo.bm_customers
WHERE age < 0 OR age > 120

UNION ALL
SELECT
    'bm_promotions',
    'end_before_start',
    COUNT(*)
FROM dbo.bm_promotions
WHERE end_date < start_date

UNION ALL
SELECT
    'bm_promotions',
    'invalid_discount',
    COUNT(*)
FROM dbo.bm_promotions
WHERE discount_pct < 0 OR discount_pct > 100;

-- 3) Duplicate checks
SELECT
    'bm_customers' AS table_name,
    'duplicate_cust_id' AS issue,
    COUNT(*) AS issue_count
FROM (
    SELECT cust_id
    FROM dbo.bm_customers
    GROUP BY cust_id
    HAVING COUNT(*) > 1
) x

UNION ALL
SELECT
    'bm_stores',
    'duplicate_store_id',
    COUNT(*)
FROM (
    SELECT store_id
    FROM dbo.bm_stores
    GROUP BY store_id
    HAVING COUNT(*) > 1
) x

UNION ALL
SELECT
    'bm_skus',
    'duplicate_sku_id',
    COUNT(*)
FROM (
    SELECT sku_id
    FROM dbo.bm_skus
    GROUP BY sku_id
    HAVING COUNT(*) > 1
) x;
