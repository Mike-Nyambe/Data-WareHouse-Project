/*
===============================================================================
 Script:      show_cleansed_sales_details.sql
 Purpose:     Cleanse and load crm_sales_details from the Bronze layer to the Silver layer.
              Applying standard rules for trim, date logic, and financial metrics.
===============================================================================
*/

USE KyinduDataWarehouse;
GO

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
    -- Trim whitespace from primary/foreign keys
    TRIM(sls_ord_num) AS sls_ord_num,
    TRIM(sls_prd_key) AS sls_prd_key,
    sls_cust_id,
    
    -- Format dates to DATE data type, mapping invalid / zero dates to NULL
    CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
    END AS sls_order_dt,
    CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt,
    CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
         ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
    END AS sls_due_dt,
    
    -- Handle missing/negative sales amounts, ensuring consistency with (quantity * price)
    CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
         THEN sls_quantity * ABS(sls_price)
         ELSE sls_sales
    END AS sls_sales,
    
    sls_quantity,
    
    -- Derive missing or negative unit price using sales and quantity
    CASE WHEN sls_price IS NULL OR sls_price <= 0
         THEN sls_sales / NULLIF(sls_quantity, 0)
         ELSE sls_price
    END AS sls_price
FROM bronze.crm_sales_details;

PRINT '>> Rows loaded into silver.crm_sales_details: '
    + CAST(@@ROWCOUNT AS NVARCHAR);
GO


