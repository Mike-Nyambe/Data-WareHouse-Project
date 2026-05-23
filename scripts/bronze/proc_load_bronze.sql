/*
===============================================================================
 Stored Procedure: bronze.load_bronze
 Purpose:     Full-refresh load of the Bronze layer from the CRM and ERP CSVs.
              For each source table, the procedure truncates the Bronze table
              and bulk-inserts the latest extract from disk.

 Behavior:
   * Idempotent — safe to re-run; previous Bronze data is overwritten.
   * Per-table timing via PRINT; total batch duration printed at the end.
   * TRY/CATCH wraps the whole batch; on failure, error details are printed
     and the original error is re-raised so the caller sees a failure.

 Usage:       EXEC bronze.load_bronze;

 Requires:
   * The Bronze tables must already exist (run scripts/bronze/ddl_bronze.sql).
   * The SQL Server service account must have READ access to the CSV paths
     below. Update the paths if the repo lives elsewhere than
     C:\Users\CRC\Desktop\Data-WareHouse-Project.
===============================================================================
*/

USE DataWarehouse;
GO

IF OBJECT_ID('bronze.load_bronze', 'P') IS NOT NULL
    DROP PROCEDURE bronze.load_bronze;
GO

CREATE PROCEDURE bronze.load_bronze AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @start_time        DATETIME2,
        @end_time          DATETIME2,
        @batch_start_time  DATETIME2,
        @batch_end_time    DATETIME2;

    BEGIN TRY
        SET @batch_start_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        -- ---------------------------------------------------------------
        -- CRM source files
        -- ---------------------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -- crm_cust_info ---------------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting Data Into: bronze.crm_cust_info';
        BULK INSERT bronze.crm_cust_info
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- crm_prd_info ----------------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into: bronze.crm_prd_info';
        BULK INSERT bronze.crm_prd_info
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- crm_sales_details -----------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into: bronze.crm_sales_details';
        BULK INSERT bronze.crm_sales_details
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- ---------------------------------------------------------------
        -- ERP source files
        -- ---------------------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        -- erp_cust_az12 ---------------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- erp_loc_a101 ----------------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- erp_px_cat_g1v2 -------------------------------------------------
        SET @start_time = SYSDATETIME();
        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'C:\Users\CRC\Desktop\Data-WareHouse-Project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(MILLISECOND, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>>--------------------------------------------';

        -- ---------------------------------------------------------------
        -- Wrap up
        -- ---------------------------------------------------------------
        SET @batch_end_time = SYSDATETIME();
        PRINT '================================================';
        PRINT 'Bronze Layer Load Complete';
        PRINT 'Total Duration: '
            + CAST(DATEDIFF(MILLISECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' ms';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LOAD';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State:   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
        THROW;
    END CATCH
END;
GO
