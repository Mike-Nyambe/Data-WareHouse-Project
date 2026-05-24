/*
===============================================================================
 Script:      proc_load_silver.sql
 Purpose:     Transform Bronze rows into the Silver layer — cleansed,
              standardized, and deduplicated. Each section handles one
              source table; sections will be added as Silver is built out
              and eventually wrapped into a single silver.load_silver
              procedure (mirrors bronze.load_bronze).

  Sections so far:
    * bronze.crm_cust_info      →  silver.crm_cust_info
    * bronze.crm_prd_info       →  silver.crm_prd_info
    * bronze.crm_sales_details  →  silver.crm_sales_details

  Behavior:
   * TRUNCATE before INSERT — Silver is a full-refresh layer.
   * ROW_NUMBER() window keeps the most recent row per business key when
     the source carries duplicates (latest cst_create_date wins).
   * Whitespace trimmed, code values expanded (M/F → Male/Female, etc.).
   * Rows with a NULL business key are discarded.
===============================================================================
*/

USE KyinduDataWarehouse;
GO


-- =============================================================================
-- silver.crm_cust_info  ←  bronze.crm_cust_info
-- =============================================================================

PRINT '>> Truncating Table: silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;

PRINT '>> Inserting Data Into: silver.crm_cust_info';
INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname)                         AS cst_firstname,
    TRIM(cst_lastname)                          AS cst_lastname,
    CASE UPPER(TRIM(cst_marital_status))
        WHEN 'M' THEN 'Married'
        WHEN 'S' THEN 'Single'
        ELSE 'n/a'
    END                                         AS cst_marital_status,
    CASE UPPER(TRIM(cst_gndr))
        WHEN 'M' THEN 'Male'
        WHEN 'F' THEN 'Female'
        ELSE 'n/a'
    END                                         AS cst_gndr,
    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL    -- drop rows that have no business key to partition on
) ranked
WHERE flag_last = 1;            -- keep only the most recent row per cst_id

PRINT '>> Rows loaded into silver.crm_cust_info: '
    + CAST(@@ROWCOUNT AS NVARCHAR);
GO


-- =============================================================================
-- silver.crm_prd_info  ←  bronze.crm_prd_info
-- =============================================================================
-- Notes on the transformation:
--   * The bronze prd_key (e.g. 'CO-RF-FR-R92B-58') encodes two things —
--     a 5-char category prefix and the actual product SKU. Silver splits
--     these apart so we can join cleanly to:
--         erp_px_cat_g1v2.id   (via cat_id, with '-' replaced by '_')
--         sales_details.sls_prd_key  (via the trimmed prd_key)
--   * prd_end_dt is rebuilt from a LEAD window — the end of one version is
--     the day before the next version's start date, and the latest version
--     gets NULL (still active). This converts the source's per-row dates
--     into a clean SCD-style validity timeline.

PRINT '>> Truncating Table: silver.crm_prd_info';
TRUNCATE TABLE silver.crm_prd_info;

PRINT '>> Inserting Data Into: silver.crm_prd_info';
INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')             AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key))                     AS prd_key,
    prd_nm,
    ISNULL(prd_cost, 0)                                     AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END                                                     AS prd_line,
    prd_start_dt,
    DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (
        PARTITION BY prd_key                                -- partitions on the ORIGINAL bronze prd_key (OVER cannot see SELECT aliases)
        ORDER BY prd_start_dt
    ))                                                      AS prd_end_dt
FROM bronze.crm_prd_info;

PRINT '>> Rows loaded into silver.crm_prd_info: '
    + CAST(@@ROWCOUNT AS NVARCHAR);
GO


-- =============================================================================
-- silver.crm_sales_details  ←  bronze.crm_sales_details
-- =============================================================================

PRINT '>> Truncating Table: silver.crm_sales_details';
TRUNCATE TABLE silver.crm_sales_details;

PRINT '>> Inserting Data Into: silver.crm_sales_details';
INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT
    TRIM(sls_ord_num) AS sls_ord_num,
    TRIM(sls_prd_key) AS sls_prd_key,
    sls_cust_id,
    CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
    END AS sls_order_dt,
    CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt,
    CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
    END AS sls_due_dt,
    CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
         THEN sls_quantity * ABS(sls_price)
         ELSE sls_sales
    END AS sls_sales,
    sls_quantity,
    CASE WHEN sls_price IS NULL OR sls_price <= 0
         THEN sls_sales / NULLIF(sls_quantity, 0)
         ELSE sls_price
    END AS sls_price
FROM bronze.crm_sales_details;

PRINT '>> Rows loaded into silver.crm_sales_details: '
    + CAST(@@ROWCOUNT AS NVARCHAR);
GO
