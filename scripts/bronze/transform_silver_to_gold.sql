-- ================================================================================
-- 'gold.dim_customer'
-- ================================================================================
-- Combine all customer data from silver tables 
SELECT 
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname, 
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Check any duplication of cst_id
-- Expected Result : No Results
SELECT cst_id, COUNT(*) FROM(
SELECT 
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname, 
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid
)t 
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Check two columns of gender 
SELECT DISTINCT
	ci.cst_gndr,
	ca.gen,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A') 
	END AS new_gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid
ORDER BY 1,2;

-- Add new_gender column to the silver.crm_cust_info ci
SELECT 
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname, 
	ci.cst_marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A') 
	END AS new_gen,
	ci.cst_create_date,
	ca.bdate,
	la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Rename object names to friendly, meaningful names
-- Naming conventions using snake_case
-- Use English for all names
-- Avoid Reserved Words, do not use SQL reserved words as object names
SELECT 
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name, 
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A') 
	END AS gender,
	ci.cst_create_date AS create_date,
	ca.bdate AS birthdate,
	la.cntry AS country
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Sort the columns into logical groups to improve readibility
SELECT 
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name, 
	la.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A')
	END AS gender,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Create Surrogate Key: System-generated unique identifier assigned to each record in a table
SELECT 
	ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name, 
	la.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A')
	END AS gender,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Create View Table: gold.dim_customer
CREATE VIEW gold.dim_customer AS
SELECT 
	ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name, 
	la.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN cst_gndr -- CRM is the Master data for gender info
		ELSE COALESCE(ca.gen, 'N/A')
	END AS gender,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

-- Quality check of the Gold table for customer dimension
SELECT * FROM gold.dim_customer

-- Quality check of gender column from gold.dim_customer
-- Expected Result: Male, Female, N/A
SELECT DISTINCT gender FROM gold.dim_customer


-- ================================================================================
-- 'gold.dim_product'
-- ================================================================================
-- Checking the product end date, if its NULL means product is still existing
SELECT 
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
FROM silver.crm_prd_info;

-- Transform the table by filtering only product contains NULL prd_end_dt
-- Remove the prd_end_dt column
SELECT 
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt
FROM silver.crm_prd_info
WHERE prd_end_dt IS NULL; -- Filter out all historical data

-- Combine crm table with erp table that has product info in silver layer
SELECT 
	pn.prd_id,
	pn.cat_id,
	pn.prd_key,
	pn.prd_nm,
	pn.prd_cost,
	pn.prd_line,
	pn.prd_start_dt,
	pc.cat,
	pc.subcat,
	pc.maintenance
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL; 

-- Check any duplication after joins
-- Expected Result: No Results
SELECT prd_key, COUNT(*) FROM (
SELECT 
	pn.prd_id,
	pn.cat_id,
	pn.prd_key,
	pn.prd_nm,
	pn.prd_cost,
	pn.prd_line,
	pn.prd_start_dt,
	pc.cat,
	pc.subcat,
	pc.maintenance
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL) t
GROUP BY prd_key
HAVING COUNT(*) > 1;

-- Sort the columns into logical groups to improve readibility
SELECT 
	pn.prd_id,
	pn.prd_key,
	pn.prd_nm,
	pn.cat_id,
	pc.cat,
	pc.subcat,
	pc.maintenance,
	pn.prd_cost,
	pn.prd_line,
	pn.prd_start_dt
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL; 

-- Rename object names to friendly, meaningful names
-- Naming conventions using snake_case
-- Use English for all names
-- Avoid Reserved Words, do not use SQL reserved words as object names
SELECT 
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL;

-- Create Surrogate Key: System-generated unique identifier assigned to each record in a table
SELECT 
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL;

-- Create View Table: gold.dim_product
CREATE VIEW gold.dim_product AS 
SELECT 
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL; 

-- Quality check of the Gold table for product dimension
SELECT * FROM gold.dim_product

-- ================================================================================
-- 'gold.fact_sales'
-- ================================================================================
-- Determine fact table or dimension table
SELECT 
	sls_order_num,
	sls_prd_key, -- Original ID
	sls_cust_id, -- Original ID
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price 
FROM silver.crm_sls_details;

-- Use the dimension's surrogate keys instead of IDs to easily connect facts with dimension 
-- Join silver layer with gold layer (dim.product and dim.customer)
SELECT 
	sd.sls_order_num,
	pr.product_key, -- replace prd_key with surrogate key from gold.dim_product
	cu.customer_key, -- replace sls_cust_id with surrogate key from gold.dim_customer 
	sd.sls_order_dt,
	sd.sls_ship_dt,
	sd.sls_due_dt,
	sd.sls_sales,
	sd.sls_quantity,
	sd.sls_price 
FROM silver.crm_sls_details sd
LEFT JOIN gold.dim_product pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customer cu
ON sd.sls_cust_id = cu.customer_id
ORDER BY sls_order_num;

-- Rename object names to friendly, meaningful names
-- Naming conventions using snake_case
-- Use English for all names
-- Avoid Reserved Words, do not use SQL reserved words as object names
SELECT 
	sd.sls_order_num AS order_number,
	pr.product_key,
	cu.customer_key, 
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price 
FROM silver.crm_sls_details sd
LEFT JOIN gold.dim_product pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customer cu
ON sd.sls_cust_id = cu.customer_id;

-- Sort the columns into logical groups to improve readibility
-- Expected Result : proper grouping in column arrangement
SELECT 
	sd.sls_order_num AS order_number,
	pr.product_key,
	cu.customer_key, 
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price 
FROM silver.crm_sls_details sd
LEFT JOIN gold.dim_product pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customer cu
ON sd.sls_cust_id = cu.customer_id;

-- Create Fact Table: gold.fact_sales
DROP VIEW  gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT 
	sd.sls_order_num AS order_number,
	pr.product_key,
	cu.customer_key, 
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price 
FROM silver.crm_sls_details sd
LEFT JOIN gold.dim_product pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customer cu
ON sd.sls_cust_id = cu.customer_id;

-- Foreign Key Integrity (Dimensions)
-- Expect Result: No Result
SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customer c
ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;

SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customer c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_product p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL;



