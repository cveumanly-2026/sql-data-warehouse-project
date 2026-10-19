/*
===============================================================================
Quality Checks
===============================================================================

Script Purpose:
    This script performs various quality checks for data consistency, accuracy,
    and standardization across the 'silver' schemas. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- =====================================================================
-- Checking 'silver.crm_cust_info'
-- =====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted Spaces from table silver.crm_cust_info
-- Expectation: No Results 
SELECT 
cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT 
cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Data Standardization & Consistency
-- Expectation: 
-- All values for marital status should be standardized to Single, Married; 
-- All values for gender should be standardized to Male, Female, or N/A.
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;

SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

-- =====================================================================
-- Checking 'silver.crm_prd_info'
-- =====================================================================
-- Check for Nulls or Duplicates in Primary Key
-- Expectation: No Result
SELECT 
	prd_id,
	COUNT (*)
FROM silver.crm_prd_info 
GROUP BY prd_id
HAVING COUNT(*) > 1 or prd_id IS NULL; 

-- Check for unwanted Spaces
-- Expectation: No Results
SELECT prd_nm
FROM silver.crm_prd_info 
WHERE prd_nm != TRIM(prd_nm);

SELECT prd_line
FROM silver.crm_prd_info 
WHERE prd_line != TRIM(prd_line);

-- Check for NULLS or Negative Numbers 
-- Expectation: No Results
SELECT prd_cost
FROM silver.crm_prd_info 
WHERE prd_cost < 0 OR prd_cost IS NULL; 

-- Data Standardization & Consistency
-- Expectation: All values should be standardized and limited to
-- Mountain, Road, Other, Touring, or N/A. 
SELECT DISTINCT prd_line
FROM silver.crm_prd_info;  

-- Check for Invalid Dates
-- Expectation: No Results
SELECT *
FROM silver.crm_prd_info 
WHERE prd_end_dt < prd_start_dt; 

-- =====================================================================
-- Checking 'silver.crm_sls_details'
-- =====================================================================
-- Check for Invalid Data Orders
-- Expectation: No Results
SELECT *
FROM silver.crm_sls_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Check Data Consistency: Between Sales, Quantity, and Price
-- >> Sales = Quantity * Price 
-- >> Values must not be NULL, Zero, or Negative
-- Expectation: No Results
SELECT 
	sls_sales,
	sls_quantity,
	sls_price
FROM silver.crm_sls_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <=0 OR sls_quantity <=0 OR sls_price <0
ORDER BY sls_sales;
