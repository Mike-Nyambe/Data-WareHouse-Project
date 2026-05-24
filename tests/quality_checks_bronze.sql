/*
===============================================================================
 Script:      quality_checks_bronze.sql
 Purpose:     Profile and validate the Bronze layer after loading from CSV.
              Each check is designed so that ZERO rows = healthy data; any
              rows returned highlight a quality issue to fix in source or
              handle during Silver transformations.

 Coverage:
   * NULLs in primary / business keys
   * Duplicate primary keys
   * Leading / trailing whitespace in text columns
   * Out-of-range numeric values (negative or zero cost, quantity, price)
   * Date sanity — start > end, future birth dates, invalid YYYYMMDD ints
   * Cross-column consistency (sls_sales = sls_quantity * sls_price)
   * Cardinality profiling of low-cardinality columns (review distinct values)

 Run as:      Read-only. Safe to execute against any environment.
              Run AFTER bronze.load_bronze has populated the tables.
===============================================================================
*/

USE KyinduDataWarehouse;
GO


-- =============================================================================
-- bronze.crm_cust_info
-- =============================================================================

-- NULL or duplicate primary key (cst_id)
-- Expectation: No rows
SELECT
    cst_id,
    COUNT(*) AS dup_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- NULL business key (cst_key)
-- Expectation: No rows
SELECT *
FROM bronze.crm_cust_info
WHERE cst_key IS NULL;

-- Leading / trailing whitespace in text columns
-- Expectation: No rows
SELECT cst_key       FROM bronze.crm_cust_info WHERE cst_key       != TRIM(cst_key);
SELECT cst_firstname FROM bronze.crm_cust_info WHERE cst_firstname != TRIM(cst_firstname);
SELECT cst_lastname  FROM bronze.crm_cust_info WHERE cst_lastname  != TRIM(cst_lastname);

-- Cardinality profiling — review distinct values so Silver can standardize them
SELECT DISTINCT cst_gndr           FROM bronze.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info;


-- =============================================================================
-- bronze.crm_prd_info
-- =============================================================================

-- NULL or duplicate primary key (prd_id)
-- Expectation: No rows
SELECT
    prd_id,
    COUNT(*) AS dup_count
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- NULL business key (prd_key)
-- Expectation: No rows
SELECT *
FROM bronze.crm_prd_info
WHERE prd_key IS NULL;

-- Whitespace in text columns
-- Expectation: No rows
SELECT prd_key  FROM bronze.crm_prd_info WHERE prd_key  != TRIM(prd_key);
SELECT prd_nm   FROM bronze.crm_prd_info WHERE prd_nm   != TRIM(prd_nm);
SELECT prd_line FROM bronze.crm_prd_info WHERE prd_line != TRIM(prd_line);

-- Negative cost (clearly invalid). NULL cost is reported separately so you
-- can decide whether to impute or treat as missing in Silver.
-- Expectation: No negative rows; NULL count should be reviewed.
SELECT * FROM bronze.crm_prd_info WHERE prd_cost < 0;
SELECT COUNT(*) AS null_cost_count FROM bronze.crm_prd_info WHERE prd_cost IS NULL;

-- Invalid date range: start later than end
-- Expectation: No rows
SELECT *
FROM bronze.crm_prd_info
WHERE prd_start_dt > prd_end_dt;

-- Cardinality profiling
SELECT DISTINCT prd_line FROM bronze.crm_prd_info;


-- =============================================================================
-- bronze.crm_sales_details
-- =============================================================================

-- Whitespace in text columns
-- Expectation: No rows
SELECT sls_ord_num FROM bronze.crm_sales_details WHERE sls_ord_num != TRIM(sls_ord_num);
SELECT sls_prd_key FROM bronze.crm_sales_details WHERE sls_prd_key != TRIM(sls_prd_key);

-- Invalid date integers (raw YYYYMMDD format — must be 8 digits in range
-- 19000101..99991231 to be safe to convert to DATE in Silver).
-- Expectation: No rows
SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
   OR LEN(CAST(sls_order_dt AS NVARCHAR)) != 8
   OR sls_order_dt > 99991231
   OR sls_order_dt < 19000101;

SELECT sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0
   OR LEN(CAST(sls_ship_dt AS NVARCHAR)) != 8
   OR sls_ship_dt > 99991231
   OR sls_ship_dt < 19000101;

SELECT sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(CAST(sls_due_dt AS NVARCHAR)) != 8
   OR sls_due_dt > 99991231
   OR sls_due_dt < 19000101;

-- Order date should not be after ship or due date
-- Expectation: No rows
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Non-positive or NULL amounts — sales / quantity / price should all be > 0
-- Expectation: No rows
SELECT *
FROM bronze.crm_sales_details
WHERE sls_sales    <= 0 OR sls_sales    IS NULL
   OR sls_quantity <= 0 OR sls_quantity IS NULL
   OR sls_price    <= 0 OR sls_price    IS NULL;

-- Cross-column consistency: sales should equal quantity * price
-- Expectation: No rows
SELECT *
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price;


-- =============================================================================
-- bronze.erp_cust_az12
-- =============================================================================

-- Whitespace
-- Expectation: No rows
SELECT cid FROM bronze.erp_cust_az12 WHERE cid != TRIM(cid);
SELECT gen FROM bronze.erp_cust_az12 WHERE gen != TRIM(gen);

-- NULL customer id
-- Expectation: No rows
SELECT * FROM bronze.erp_cust_az12 WHERE cid IS NULL;

-- Birth date sanity — no future dates, and nothing older than 120 years
-- Expectation: No rows
SELECT * FROM bronze.erp_cust_az12 WHERE bdate > GETDATE();
SELECT * FROM bronze.erp_cust_az12 WHERE bdate < DATEADD(YEAR, -120, GETDATE());

-- Cardinality profiling
SELECT DISTINCT gen FROM bronze.erp_cust_az12;


-- =============================================================================
-- bronze.erp_loc_a101
-- =============================================================================

-- Whitespace
-- Expectation: No rows
SELECT cid   FROM bronze.erp_loc_a101 WHERE cid   != TRIM(cid);
SELECT cntry FROM bronze.erp_loc_a101 WHERE cntry != TRIM(cntry);

-- NULL customer id
-- Expectation: No rows
SELECT * FROM bronze.erp_loc_a101 WHERE cid IS NULL;

-- Cardinality profiling — review country values for standardization
-- (e.g. 'USA' vs 'United States' vs 'US')
SELECT DISTINCT cntry FROM bronze.erp_loc_a101 ORDER BY cntry;


-- =============================================================================
-- bronze.erp_px_cat_g1v2
-- =============================================================================

-- Whitespace across all text columns
-- Expectation: No rows
SELECT id          FROM bronze.erp_px_cat_g1v2 WHERE id          != TRIM(id);
SELECT cat         FROM bronze.erp_px_cat_g1v2 WHERE cat         != TRIM(cat);
SELECT subcat      FROM bronze.erp_px_cat_g1v2 WHERE subcat      != TRIM(subcat);
SELECT maintenance FROM bronze.erp_px_cat_g1v2 WHERE maintenance != TRIM(maintenance);

-- Duplicate id (category id should be unique)
-- Expectation: No rows
SELECT
    id,
    COUNT(*) AS dup_count
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL;

-- Cardinality profiling
SELECT DISTINCT cat         FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2;
