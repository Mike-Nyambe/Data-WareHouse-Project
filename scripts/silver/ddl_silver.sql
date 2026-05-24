/*
===============================================================================
 Script:      ddl_silver.sql
 Purpose:     Define the Silver-layer tables for the CRM and ERP source
              systems. The Silver layer holds cleansed, standardized rows
              produced by transforming Bronze — type-corrected, trimmed,
              deduplicated, and ready for the Gold modeling layer.

 Tables created:
   silver.crm_cust_info        ← datasets/source_crm/cust_info.csv
   silver.crm_prd_info         ← datasets/source_crm/prd_info.csv
   silver.crm_sales_details    ← datasets/source_crm/sales_details.csv
   silver.erp_cust_az12        ← datasets/source_erp/CUST_AZ12.csv
   silver.erp_loc_a101         ← datasets/source_erp/LOC_A101.csv
   silver.erp_px_cat_g1v2      ← datasets/source_erp/PX_CAT_G1V2.csv

 Run against: the KyinduDataWarehouse database, after database_initialization.sql
              has created the `silver` schema.
===============================================================================

 !!  WARNING — DESTRUCTIVE OPERATION  !!
 -----------------------------------------------------------------------------
 Each table is dropped and recreated. ALL existing data in the silver tables
 listed above will be PERMANENTLY LOST when this script runs. There is no
 rollback.

 This is intentional — Silver is a full-refresh layer rebuilt from Bronze
 on every load. Only run this on a development environment or as part of
 a controlled rebuild of the warehouse.
===============================================================================
*/

USE KyinduDataWarehouse;
GO


-- =============================================================================
-- CRM source tables
-- =============================================================================

IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE,
    dwh_load_date       DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO


IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),  -- derived from the first 5 chars of bronze prd_key (joins to erp_px_cat_g1v2.id)
    prd_key         NVARCHAR(50),  -- bronze prd_key from position 7 onward (joins to sales_details.sls_prd_key)
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_load_date   DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO


IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,          -- converted from YYYYMMDD INT in Bronze
    sls_ship_dt     DATE,          -- converted from YYYYMMDD INT in Bronze
    sls_due_dt      DATE,          -- converted from YYYYMMDD INT in Bronze
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_load_date   DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO


-- =============================================================================
-- ERP source tables
-- =============================================================================

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid     NVARCHAR(50),
    bdate   DATE,
    gen     NVARCHAR(50),
    dwh_load_date   DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO


IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid     NVARCHAR(50),
    cntry   NVARCHAR(50),
    dwh_load_date   DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO


IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50),
    dwh_load_date   DATETIME2(0) DEFAULT GETDATE()  -- capture when the row was loaded into Silver
);
GO
