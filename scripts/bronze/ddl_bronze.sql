/*
===============================================================================
 Script:      ddl_bronze.sql
 Purpose:     Define the Bronze-layer tables for the CRM and ERP source
              systems. The Bronze layer lands raw rows from the source CSVs
              with minimal typing — cleaning happens downstream in Silver.

 Tables created:
   bronze.crm_cust_info        ← datasets/source_crm/cust_info.csv
   bronze.crm_prd_info         ← datasets/source_crm/prd_info.csv
   bronze.crm_sales_details    ← datasets/source_crm/sales_details.csv
   bronze.erp_cust_az12        ← datasets/source_erp/CUST_AZ12.csv
   bronze.erp_loc_a101         ← datasets/source_erp/LOC_A101.csv
   bronze.erp_px_cat_g1v2      ← datasets/source_erp/PX_CAT_G1V2.csv

 Run against: the DataWarehouse database, after database_initialization.sql
              has created the `bronze` schema.
===============================================================================

 !!  WARNING — DESTRUCTIVE OPERATION  !!
 -----------------------------------------------------------------------------
 Each table is dropped and recreated. ALL existing data in the Bronze tables
 listed above will be PERMANENTLY LOST when this script runs. There is no
 rollback.

 This is intentional — Bronze is a full-refresh layer that mirrors the
 latest source extract. Only run this on a development environment or as
 part of a controlled rebuild of the warehouse.
===============================================================================
*/

USE DataWarehouse;
GO


-- =============================================================================
-- CRM source tables
-- =============================================================================

IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO


IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id          INT,
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE
);
GO


IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    INT,           -- raw YYYYMMDD from source; cleaned in Silver
    sls_ship_dt     INT,           -- raw YYYYMMDD from source; cleaned in Silver
    sls_due_dt      INT,           -- raw YYYYMMDD from source; cleaned in Silver
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT
);
GO


-- =============================================================================
-- ERP source tables
-- =============================================================================

IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    cid     NVARCHAR(50),
    bdate   DATE,
    gen     NVARCHAR(50)
);
GO


IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    cid     NVARCHAR(50),
    cntry   NVARCHAR(50)
);
GO


IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id              NVARCHAR(50),
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50)
);
GO
