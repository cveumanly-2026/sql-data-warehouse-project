/*
===============================================================================
Stored Procedure: Load Bronze Layer (Staging Ingestion)
===============================================================================
Script Purpose:
    This stored procedure automates the ETL/Ingestion process for the Bronze layer.
    It truncates (empties) existing staging tables and bulk-loads raw data from 
    external CSV files (CRM and ERP source domains).

Features:
    - Truncate & Load strategy to ensure clean data sets (idempotency).
    - Session tracking metrics calculating individual table and total batch load duration.
    - Error handling via TRY...CATCH blocks to log database or file ingestion failures.

Usage:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    -- Declare variables for tracking step duration and absolute batch time
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    
    BEGIN TRY
        -- Capture baseline starting timestamp for the entire batch
        SET @batch_start_time = GETDATE();
        
        PRINT '======================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '======================================================';

        PRINT '------------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------------';

        -- 1. crm_cust_info Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_cust_info'; 
        TRUNCATE TABLE bronze.crm_cust_info;
   
        PRINT '>> Inserting Data Into: bronze.crm_cust_info'; 
        BULK INSERT bronze.crm_cust_info
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_crm\cust_info.csv'
        WITH 
        (
            FIRSTROW = 2,           -- Skip header row in CSV file
            FIELDTERMINATOR = ',',  -- Comma-separated values format
            TABLOCK                 -- Optimize lock handling during bulk insert
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds'; 

        -- 2. crm_prd_info Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_prd_info'; 
        TRUNCATE TABLE bronze.crm_prd_info;  
    
        PRINT '>> Inserting Data Into: bronze.crm_prd_info'; 
        BULK INSERT bronze.crm_prd_info 
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_crm\prd_info.csv'
        WITH 
        (
	        FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds'; 

        -- 3. crm_sls_details Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_sls_details'; 
        TRUNCATE TABLE bronze.crm_sls_details;

        PRINT '>> Inserting Data Into: bronze.crm_sls_details';
        BULK INSERT bronze.crm_sls_details
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_crm\sales_details.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds'; 


        PRINT '------------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------------';

        -- 4. erp_loc_a101 Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_loc_a101'; 
        TRUNCATE TABLE bronze.erp_loc_a101; 

        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_erp\loc_a101.csv'
        WITH
        (
	        FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds'; 

        -- 5. erp_cust_az12 Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_cust_az12'; 
        TRUNCATE TABLE bronze.erp_cust_az12; 

        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_erp\cust_az12.csv' 
        WITH
        (
	        FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';  

        -- 6. erp_px_cat_g1v2 Table Processing
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2'; 
        TRUNCATE TABLE bronze.erp_px_cat_g1v2; 

        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2 
        FROM 'C:\SQL_DataWarehouse_Project\datasets\source_erp\px_cat_g1v2.csv' 
        WITH 
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';  
        PRINT '>> -------------';

        -- Calculate absolute batch end runtime metrics
        SET @batch_end_time = GETDATE();
        PRINT '======================================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND,@batch_start_time, @batch_end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '======================================================';

    END TRY
    BEGIN CATCH
        -- Capture and log structural execution failures safely without breaking terminal state
        PRINT '======================================================'
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: '  + CAST (ERROR_NUMBER() AS NVARCHAR(10));
        PRINT 'Error State: '   + CAST (ERROR_STATE() AS NVARCHAR(10));
        PRINT '======================================================'
    END CATCH
END;
GO
