
/*
===============================================================================
Bronze-to-Silver Transformation Documentation
===============================================================================

Script Purpose:
    This script documents and previews the data transformations performed
    when moving data from the Bronze layer to the Silver layer.

    It investigates raw data, identifies data-quality issues, and previews
    the transformation rules before the data is inserted into Silver.

Transformation Activities:
    - Deduplicate customer records.
    - Trim unwanted spaces.
    - Standardize categorical values.
    - Split product keys into category and product identifiers.
    - Handle missing and invalid numeric values.
    - Convert raw date representations into SQL DATE values.
    - Correct invalid sales and price values.
    - Standardize ERP customer and location identifiers.
    - Validate relationships between related source tables.

Important:
    This script is for investigation and transformation previews only.
    It does not modify Bronze tables or insert records into Silver.
    Actual loading is performed by silver.load_silver.

===============================================================================
*/


-- =====================================================================
-- 1. TRANSFORMING 'bronze.crm_cust_info'
-- =====================================================================

-- Inspect the raw customer data from bronze.crm_cust_info
SELECT TOP 1000 *
FROM bronze.crm_cust_info;

-- Investigate NULLs or duplicate customer IDs
SELECT
    cst_id,
    COUNT(*) AS record_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Deduplicate customers and exclude NULL customer IDs
-- Keep the latest record according to cst_create_date
SELECT *
FROM
(
    SELECT 
        *,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) AS t
WHERE flag_last = 1;

-- Investigate unwanted spaces in customer names and marital status
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT cst_marital_status
FROM bronze.crm_cust_info
WHERE cst_marital_status != TRIM(cst_marital_status);

-- Preview cleaned customer names
SELECT
    cst_id,
    cst_key,
    cst_firstname AS old_firstname,
    TRIM(cst_firstname) AS cst_firstname,
    cst_lastname AS old_lastname,
    TRIM(cst_lastname) AS cst_lastname
FROM bronze.crm_cust_info;

-- Investigate original marital status and gender codes
SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info;

SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info;

-- Preview standardized customer attributes prior insert to silver.crm_cust_info
-- M -> Married; S -> Single
-- F -> Female; M -> Male
-- Unrecognized or missing values -> N/A
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        ELSE 'N/A'
    END AS cst_marital_status, -- Normalize marital status values to readable format
    CASE
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'N/A'
    END AS cst_gndr, -- Normalize gender values to readable format 
    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) AS t
WHERE flag_last = 1;


-- =====================================================================
-- 2. TRANSFORMING 'bronze.crm_prd_info'
-- =====================================================================
-- Inspect the raw product data
SELECT TOP 1000 *
FROM bronze.crm_prd_info;

-- Investigate NULL or duplicate product IDs
SELECT
    prd_id,
    COUNT(*) AS record_count
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Investigate unwanted spaces in product names and product lines
SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm); 

SELECT prd_line
FROM bronze.crm_prd_info
WHERE prd_line != TRIM(prd_line);

-- Separate prd_key into prd_key and cat_id and replace dash into '_'
SELECT
    prd_id,
    prd_key AS old_prd_key,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key
FROM bronze.crm_prd_info;

-- Check whether the extracted category IDs from bronze.crm_prd_info
-- exist in the category reference table bronze.erp_px_cat_g1v2.
SELECT 
	prd_key as old_prd_key,
	REPLACE(SUBSTRING (prd_key, 1,5), '-', '_') AS cat_id,
	SUBSTRING (prd_key, 7, LEN(prd_key)) AS prd_key
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING (prd_key, 1,5), '-', '_') NOT IN 
	(SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2);

-- Identify product keys in bronze.crm_prd_info that do not appear
-- in the sales records of bronze.crm_sls_details.
SELECT 
	prd_key as old_prd_key,
	REPLACE(SUBSTRING (prd_key, 1,5), '-', '_') AS cat_id,
	SUBSTRING (prd_key, 7, LEN(prd_key)) AS prd_key
FROM bronze.crm_prd_info
WHERE SUBSTRING (prd_key, 7, LEN(prd_key)) NOT IN
	(SELECT sls_prd_key FROM bronze.crm_sls_details);

-- Investigate for unwanted spaces in prd_nm and trim it
SELECT 
    prd_nm AS old_prd_nm,
    TRIM(prd_nm) AS prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);
  
-- Investigate NULL from prd_cost and transform it
SELECT
    prd_cost AS old_prd_cost,
    ISNULL(prd_cost, 0) AS prd_cost
FROM bronze.crm_prd_info;

-- Data Standardization & Consistency
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

-- Change the abbreviation with friendly value of prd_line
SELECT DISTINCT
    prd_line AS old_prd_line,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other'
        WHEN 'T' THEN 'Touring'
        ELSE 'N/A'
    END AS prd_line
FROM bronze.crm_prd_info;

-- Investigate for Invalid Data Orders
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- Fix the Invalid Data Orders
SELECT
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS prd_end_dt_TEST
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R','AC-HE-HL-U509')
FROM bronze.crm_prd_info;

-- Preview the complete transformed product dataset prior insert to silver.crm_prd_info 
SELECT
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extract category ID
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- Extract product key
    TRIM(prd_nm) AS prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other'
        WHEN 'T' THEN 'Touring'
        ELSE 'N/A'
    END AS prd_line, -- Map product line codes to descriptive values
    CAST(prd_start_dt AS DATE) prd_start_dt,
	  CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 
		    AS DATE) prd_end_dt -- Calculate end date as one day before the next start date
FROM bronze.crm_prd_info;


-- =====================================================================
-- 3. TRANSFORMING 'bronze.crm_sls_details'
-- =====================================================================

-- Inspect raw sales data
SELECT TOP 1000 *
FROM bronze.crm_sls_details;

-- Investigate for Unwanted Spaces
SELECT *
FROM bronze.crm_sls_details
WHERE sls_order_num != TRIM(sls_order_num);

SELECT *
FROM bronze.crm_sls_details
WHERE sls_prd_key != TRIM(sls_prd_key); 

-- Checking if prd_key is NOT IN prd_key from silver.crm_prd_info
SELECT *
FROM bronze.crm_sls_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- Checking if cust_id is NOT IN prd_key from silver.crm_cust_info
SELECT *
FROM bronze.crm_sls_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- Check for Invalid Dates sls_order_dt
SELECT 
	sls_order_dt AS sls_order_date1,
	NULLIF(sls_order_dt, 0) sls_order_dt
FROM bronze.crm_sls_details
WHERE sls_order_dt <= 0 
OR LEN(sls_order_dt) != 8 
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101;

-- Transform sls_order_dt from INT to DATE
SELECT 
	sls_order_dt AS sls_order_dt0,
	CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt
FROM bronze.crm_sls_details;
  
-- Check for Invalid Dates sls_ship_dt
SELECT 
	  NULLIF(sls_order_dt, 0) sls_ship_dt
FROM bronze.crm_sls_details
WHERE sls_ship_dt <= 0 
OR LEN(sls_ship_dt) != 8 
OR sls_ship_dt > 20500101
OR sls_ship_dt < 19000101; 

-- Check for Invalid Dates sls_due_dt
SELECT 
	NULLIF(sls_due_dt, 0) sls_due_dt
FROM bronze.crm_sls_details
WHERE sls_due_dt <= 0 
OR LEN(sls_due_dt) != 8 
OR sls_due_dt > 20500101
OR sls_due_dt < 19000101; 

-- Apply the transformed sls_ship_dt and sls_due_dt in DATE form
SELECT
	sls_order_num,
	sls_prd_key,
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
	sls_sales,
	sls_quantity,
	sls_price
FROM bronze.crm_sls_details;

-- Order date must always be earlier than the Shipping date or Due Date
-- Check for Invalid Data Orders

SELECT *
FROM bronze.crm_sls_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Check Data Consistency: Between Sales, Quantity, and Price
-- >> Sales = Quantity * Price 
-- >> Values must not be NULL, Zero, or Negative
SELECT 
	sls_sales AS old_sls_sales,
	sls_quantity,
	sls_price AS old_sls_price,
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
		  ELSE sls_sales 
	END AS sls_sales,
	CASE WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity, 0) 
		  ELSE sls_price 
	END AS sls_price
FROM bronze.crm_sls_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <=0 OR sls_quantity <=0 OR sls_price <0
ORDER BY sls_sales;

-- Preview the complete transformed sales dataset prior insert to silver.crm_sls_details
SELECT
	sls_order_num,
	sls_prd_key,
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
FROM bronze.crm_sls_details;
  
-- =====================================================================
-- 4. TRANSFORMING 'bronze.erp_cust_az12'
-- =====================================================================

-- Inspect raw ERP customer data
SELECT TOP 1000 *
FROM bronze.erp_cust_az12;

-- Investigate customer IDs with the NAS prefix
SELECT
	cid,
	bdate,
	gen
FROM bronze.erp_cust_az12
WHERE cid LIKE 'AW%';

-- Transform cid (customer ID) into single form 
SELECT
    cid AS old_cid,
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END AS cid,
FROM bronze.erp_cust_az12;

-- Investigate if there's unmatch cid with cst_key in silver.crm_cust_info 
SELECT
	  cid AS old_cid,
	  CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
	  ELSE cid END AS cid,
FROM bronze.erp_cust_az12
WHERE 
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING (cid, 4, LEN(cid))
	  ELSE cid
	  END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info);

-- Identify Out-of-Range Dates in bdate
SELECT DISTINCT bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- Transform the impossible bdates into NULL
SELECT DISTINCT
	bdate AS old_bdate,
	CASE WHEN bdate > GETDATE() THEN NULL
		ELSE bdate
	END AS bdate 
FROM bronze.erp_cust_az12;

-- Investigate gender values
SELECT DISTINCT gen
FROM bronze.erp_cust_az12;

-- Data Standardization & Consistency for gender values into Female, Male, or N/A
SELECT DISTINCT
	gen AS old_gen,
	CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		   WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		   ELSE 'N/A' 
	END AS gen
FROM bronze.erp_cust_az12;

-- Preview the complete transformed erp.cust dataset prior insert to silver.erp_cust_az12
SELECT
	  CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		    ELSE cid 
	  END AS cid,
	  CASE WHEN bdate > GETDATE() THEN NULL
		    ELSE bdate
	  END AS bdate, -- Set future birthdates to NULL
	  CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		     WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		     ELSE 'N/A' 
	  END AS gen -- Normalize gender values and handle unknown cases
FROM bronze.erp_cust_az12;

-- =====================================================================
-- 5. TRANSFORMING 'bronze.erp_loc_a101'
-- =====================================================================

-- Inspect raw ERP location data
SELECT TOP 1000 *
FROM bronze.erp_loc_a101;

-- Remove the dash in cid and checking the new format of cid match to cst_key from silver.crm_cust_info
SELECT 
	  cid AS old_cid,
	  REPLACE (cid, '-', '') cid
FROM bronze.erp_loc_a101
WHERE REPLACE (cid, '-', '') NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info);

-- Data Standardization & Consistency for cntry
SELECT DISTINCT
    cntry AS old_cntry,
    CASE WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
         WHEN TRIM(cntry) = 'DE' THEN 'Germany'
         WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
         ELSE TRIM(cntry)
    END AS cntry
FROM bronze.erp_loc_a101
ORDER BY cntry;


-- Preview complete transformation of ERP location data prior insert to silver.erp_loc_a101
SELECT
    REPLACE(cid, '-', '') AS cid,
    CASE WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
         WHEN TRIM(cntry) = 'DE' THEN 'Germany'
         WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
         ELSE TRIM(cntry)
    END AS cntry
FROM bronze.erp_loc_a101;

-- =====================================================================
-- 6. TRANSFORMING 'bronze.erp_px_cat_g1v2'
-- =====================================================================

-- Inspect raw ERP product-category data
SELECT TOP 1000 *
FROM bronze.erp_px_cat_g1v2;

-- Investigate unwanted spaces in category fields
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE id != TRIM(id) OR cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

-- Data Standardization & Consistency
SELECT DISTINCT cat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT subcat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT  maintenance
FROM bronze.erp_px_cat_g1v2;

-- Preview the data prior insert to silver.erp_px_cat_g1v2
-- The current load procedure transfers these fields without additional
-- standardization or transformation.

SELECT
    id,
    cat,
    subcat,
    maintenance
FROM bronze.erp_px_cat_g1v2;


/*
===============================================================================
END OF BRONZE-TO-SILVER TRANSFORMATION DOCUMENTATION
===============================================================================
*/
