-- 1. Customer RFM scores and segments
WITH     analysis_date
AS       (SELECT MAX([date]) AS max_sale_date
          FROM   dbo.bm_sales),
         customer_metrics
AS       (SELECT   c.cust_id,
                   c.city,
                   DATEDIFF(DAY, MAX(s.[date]), ad.max_sale_date) AS recency_days,
                   COUNT(s.customer_id) AS purchase_frequency,
                   COALESCE (SUM(CAST (s.total_value AS DECIMAL (18, 2))), 0) AS monetary_value
          FROM     dbo.bm_customers AS c CROSS JOIN analysis_date AS ad
                   LEFT OUTER JOIN
                   dbo.bm_sales AS s
                   ON TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) = c.cust_id
          GROUP BY c.cust_id, c.city, ad.max_sale_date),
         purchasing_customers
AS       (SELECT cm.*,
                 NTILE(5) OVER (ORDER BY recency_days ASC, cust_id) AS recency_band,
                 NTILE(5) OVER (ORDER BY purchase_frequency ASC, cust_id) AS frequency_band,
                 NTILE(5) OVER (ORDER BY monetary_value ASC, cust_id) AS monetary_band
          FROM   customer_metrics AS cm
          WHERE  purchase_frequency > 0),
         scored_customers
AS       (SELECT cm.cust_id,
                 cm.city,
                 cm.recency_days,
                 cm.purchase_frequency,
                 cm.monetary_value,
                 CASE WHEN pc.cust_id IS NULL THEN 0 ELSE 6 - pc.recency_band END AS recency_score,
                 CASE WHEN pc.cust_id IS NULL THEN 0 ELSE pc.frequency_band END AS frequency_score,
                 CASE WHEN pc.cust_id IS NULL THEN 0 ELSE pc.monetary_band END AS monetary_score
          FROM   customer_metrics AS cm
                 LEFT OUTER JOIN
                 purchasing_customers AS pc
                 ON pc.cust_id = cm.cust_id)
SELECT   cust_id,
         city,
         recency_days,
         purchase_frequency,
         monetary_value,
         recency_score,
         frequency_score,
         monetary_score,
         CONCAT(recency_score, frequency_score, monetary_score) AS rfm_code,
         CASE WHEN recency_score >= 4
                   AND frequency_score >= 4
                   AND monetary_score >= 4 THEN 'Champions' WHEN recency_score >= 3
                                                                 AND frequency_score >= 3 THEN 'Loyal' WHEN recency_score <= 2
                                                                                                            AND (frequency_score >= 3
                                                                                                                 OR monetary_score >= 3) THEN 'At Risk' ELSE 'Lost' END AS customer_segment
FROM     scored_customers
ORDER BY customer_segment, monetary_value DESC;

-- 2. Cohort retention by customer signup month
WITH     customer_cohorts
AS       (SELECT c.cust_id,
                 DATEFROMPARTS(YEAR(c.registration_date), MONTH(c.registration_date), 1) AS cohort_month
          FROM   dbo.bm_customers AS c),
         customer_activity
AS       (SELECT DISTINCT cc.cust_id,
                          cc.cohort_month,
                          DATEFROMPARTS(YEAR(s.[date]), MONTH(s.[date]), 1) AS activity_month
          FROM   customer_cohorts AS cc
                 INNER JOIN
                 dbo.bm_sales AS s
                 ON TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) = cc.cust_id
          WHERE  DATEFROMPARTS(YEAR(s.[date]), MONTH(s.[date]), 1) >= cc.cohort_month),
         cohort_sizes
AS       (SELECT   cohort_month,
                   COUNT(*) AS cohort_size
          FROM     customer_cohorts
          GROUP BY cohort_month),
         retention_counts
AS       (SELECT   ca.cohort_month,
                   DATEDIFF(MONTH, ca.cohort_month, ca.activity_month) AS months_since_signup,
                   COUNT(*) AS retained_customers
          FROM     customer_activity AS ca
          GROUP BY ca.cohort_month, DATEDIFF(MONTH, ca.cohort_month, ca.activity_month))
SELECT   rc.cohort_month,
         rc.months_since_signup,
         cs.cohort_size,
         rc.retained_customers,
         CAST (100.0 * rc.retained_customers / NULLIF (cs.cohort_size, 0) AS DECIMAL (6, 2)) AS retention_rate_pct
FROM     retention_counts AS rc
         INNER JOIN
         cohort_sizes AS cs
         ON cs.cohort_month = rc.cohort_month
ORDER BY rc.cohort_month, rc.months_since_signup;

-- 3. Top product pairs bought together
WITH     basket_products
AS       (SELECT DISTINCT s.[date],
                          s.store_id,
                          TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) AS cust_id,
                          s.sku_id
          FROM   dbo.bm_sales AS s
          WHERE  TRY_CONVERT (INT, TRY_CONVERT (DECIMAL (18, 2), s.customer_id)) IS NOT NULL),
         product_pairs
AS       (SELECT   bp1.sku_id AS sku_id_1,
                   bp2.sku_id AS sku_id_2,
                   COUNT(*) AS baskets_together
          FROM     basket_products AS bp1
                   INNER JOIN
                   basket_products AS bp2
                   ON bp2.[date] = bp1.[date]
                      AND bp2.store_id = bp1.store_id
                      AND bp2.cust_id = bp1.cust_id
                      AND bp1.sku_id < bp2.sku_id
          GROUP BY bp1.sku_id, bp2.sku_id),
         ranked_pairs
AS       (SELECT pp.sku_id_1,
                 sk1.sku_name AS product_1,
                 pp.sku_id_2,
                 sk2.sku_name AS product_2,
                 pp.baskets_together,
                 ROW_NUMBER() OVER (ORDER BY pp.baskets_together DESC, pp.sku_id_1, pp.sku_id_2) AS pair_rank
          FROM   product_pairs AS pp
                 INNER JOIN
                 dbo.bm_skus AS sk1
                 ON sk1.sku_id = pp.sku_id_1
                 INNER JOIN
                 dbo.bm_skus AS sk2
                 ON sk2.sku_id = pp.sku_id_2)
SELECT   pair_rank,
         sku_id_1,
         product_1,
         sku_id_2,
         product_2,
         baskets_together
FROM     ranked_pairs
WHERE    pair_rank <= 20
ORDER BY pair_rank;

-- 4. Year-over-year revenue growth
WITH     annual_revenue
AS       (SELECT   YEAR(s.[date]) AS sales_year,
                   SUM(CAST (s.total_value AS DECIMAL (18, 2))) AS revenue
          FROM     dbo.bm_sales AS s
          GROUP BY YEAR(s.[date])),
         revenue_comparison
AS       (SELECT sales_year,
                 revenue,
                 LAG(sales_year) OVER (ORDER BY sales_year) AS prior_sales_year,
                 LAG(revenue) OVER (ORDER BY sales_year) AS prior_year_revenue
          FROM   annual_revenue)
SELECT   sales_year,
         revenue,
         prior_sales_year,
         prior_year_revenue,
         revenue - prior_year_revenue AS revenue_change,
         CAST (100.0 * (revenue - prior_year_revenue) / NULLIF (prior_year_revenue, 0) AS DECIMAL (10, 2)) AS revenue_growth_pct
FROM     revenue_comparison
WHERE    prior_sales_year IS NULL
         OR sales_year = prior_sales_year + 1
ORDER BY sales_year;

-- 5. Running total revenue by month
WITH     monthly_revenue
AS       (SELECT   DATEFROMPARTS(YEAR(s.[date]), MONTH(s.[date]), 1) AS sales_month,
                   SUM(CAST (s.total_value AS DECIMAL (18, 2))) AS monthly_revenue
          FROM     dbo.bm_sales AS s
          GROUP BY DATEFROMPARTS(YEAR(s.[date]), MONTH(s.[date]), 1))
SELECT   sales_month,
         monthly_revenue,
         SUM(monthly_revenue) OVER (ORDER BY sales_month ROWS UNBOUNDED PRECEDING) AS running_total_revenue
FROM     monthly_revenue
ORDER BY sales_month;