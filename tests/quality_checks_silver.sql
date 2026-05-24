/*
===============================================================================
 Script:      quality_checks_silver.sql
 Purpose:     Validate the Silver layer after running proc_load_silver.sql.
              Unlike the Bronze checks (which profile raw input), the Silver
              checks verify that the transformations actually worked — any
              rows returned indicate a regression in the cleanse logic.

 Coverage:
   * Primary-key uniqueness after dedup
   * No leading/trailing whitespace remaining
   * Standardized code values only (no raw 'M'/'R'/'S' codes leak through)
   * No NULLs in columns that should have been defaulted (e.g. prd_cost)
   * Date timeline validity (prd_start_dt ≤ prd_end_dt)
   * cat_id format sanity (matches erp_px_cat_g1v2.id pattern)
   * Audit columns populated (dwh_load_date)

 Convention:  ZERO rows = clean; any returned rows = defect to investigate.
              Profiling SELECTs at the end of each section return distinct
              values for visual review.

 Run as:      Read-only. Execute AFTER proc_load_silver.sql.

  Note:        Sections are added as Silver transformations are built out.
               Current sections:
                 * silver.crm_cust_info
                 * silver.crm_prd_info
                 * silver.crm_sales_details
===============================================================================
*/

USE KyinduDataWarehouse;
GO


-- =============================================================================
-- silver.crm_cust_info
-- =============================================================================

-- Duplicate or NULL primary key — dedup window should have eliminated these
-- Expectation: No rows
SELECT
    cst_id,
    COUNT(*) AS dup_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Leading / trailing whitespace — TRIM should have removed these
-- Expectation: No rows
SELECT cst_key       FROM silver.crm_cust_info WHERE cst_key       != TRIM(cst_key);
SELECT cst_firstname FROM silver.crm_cust_info WHERE cst_firstname != TRIM(cst_firstname);
SELECT cst_lastname  FROM silver.crm_cust_info WHERE cst_lastname  != TRIM(cst_lastname);

-- Standardized marital status — only the expanded forms should appear
-- Expectation: No rows
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Married', 'Single', 'n/a')
   OR cst_marital_status IS NULL;

-- Standardized gender — only the expanded forms should appear
-- Expectation: No rows
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr NOT IN ('Male', 'Female', 'n/a')
   OR cst_gndr IS NULL;

-- Audit column populated — DEFAULT GETDATE() should have filled it
-- Expectation: No rows
SELECT * FROM silver.crm_cust_info WHERE dwh_load_date IS NULL;

-- Profiling — confirm the value distribution looks reasonable
SELECT cst_marital_status, COUNT(*) AS row_count
FROM silver.crm_cust_info GROUP BY cst_marital_status;

SELECT cst_gndr, COUNT(*) AS row_count
FROM silver.crm_cust_info GROUP BY cst_gndr;


-- =============================================================================
-- silver.crm_prd_info
-- =============================================================================

-- Duplicate or NULL primary key
-- Expectation: No rows
SELECT
    prd_id,
    COUNT(*) AS dup_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Whitespace
-- Expectation: No rows
SELECT cat_id  FROM silver.crm_prd_info WHERE cat_id  != TRIM(cat_id);
SELECT prd_key FROM silver.crm_prd_info WHERE prd_key != TRIM(prd_key);
SELECT prd_nm  FROM silver.crm_prd_info WHERE prd_nm  != TRIM(prd_nm);

-- prd_cost: ISNULL(prd_cost, 0) was applied, so NULL should be impossible
-- and negative values would still be a data error.
-- Expectation: No rows
SELECT * FROM silver.crm_prd_info WHERE prd_cost IS NULL;
SELECT * FROM silver.crm_prd_info WHERE prd_cost < 0;

-- Standardized product line — only the expanded forms should appear
-- Expectation: No rows
SELECT DISTINCT prd_line
FROM silver.crm_prd_info
WHERE prd_line NOT IN ('Mountain', 'Road', 'Other Sales', 'Touring', 'n/a')
   OR prd_line IS NULL;

-- Date timeline: a non-NULL end date should not precede the start.
-- (NULL end date = "still active" — the latest version per product.)
-- Expectation: No rows
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_start_dt > prd_end_dt;

-- Exactly one open-ended (NULL end_dt) version per product
-- Expectation: No rows
SELECT
    prd_key,
    COUNT(*) AS open_versions
FROM silver.crm_prd_info
WHERE prd_end_dt IS NULL
GROUP BY prd_key
HAVING COUNT(*) > 1;

-- cat_id format: 5 chars, underscore at position 3 (e.g. 'CO_RF', 'AC_BR')
-- Expectation: No rows
SELECT DISTINCT cat_id
FROM silver.crm_prd_info
WHERE LEN(cat_id) != 5
   OR SUBSTRING(cat_id, 3, 1) != '_';

-- cat_id should match a row in bronze.erp_px_cat_g1v2 (silver erp not loaded yet).
-- Orphans are tolerable for now but worth tracking — review the list.
SELECT DISTINCT p.cat_id
FROM silver.crm_prd_info p
LEFT JOIN bronze.erp_px_cat_g1v2 c ON c.id = p.cat_id
WHERE c.id IS NULL;

-- Audit column populated
-- Expectation: No rows
SELECT * FROM silver.crm_prd_info WHERE dwh_load_date IS NULL;

-- Profiling
SELECT prd_line, COUNT(*) AS row_count
FROM silver.crm_prd_info GROUP BY prd_line;

SELECT cat_id, COUNT(*) AS row_count
FROM silver.crm_prd_info GROUP BY cat_id ORDER BY cat_id;


-- =============================================================================
-- silver.crm_sales_details
-- =============================================================================

-- Whitespace check
-- Expectation: No rows
SELECT sls_ord_num FROM silver.crm_sales_details WHERE sls_ord_num != TRIM(sls_ord_num);
SELECT sls_prd_key FROM silver.crm_sales_details WHERE sls_prd_key != TRIM(sls_prd_key);

-- Integrity check: Sales, Qty, Price should all be > 0 (nulls not allowed)
-- Expectation: No rows
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales <= 0 OR sls_sales IS NULL
   OR sls_quantity <= 0 OR sls_quantity IS NULL
   OR sls_price <= 0 OR sls_price IS NULL;

-- Date order checks: order date should be <= ship date and <= due date
-- Expectation: No rows
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Sales column consistency check: sales = quantity * price
-- Expectation: No rows
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price;

-- Audit column populated
-- Expectation: No rows
SELECT * FROM silver.crm_sales_details WHERE dwh_load_date IS NULL;

