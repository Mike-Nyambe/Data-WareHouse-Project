/*
===============================================================================
 Script:      ddl_gold.sql
 Purpose:     Define the Gold-layer views. The Gold layer holds dimensional
              models (stars) for reporting.
 
 Views created:
   gold.vw_customer_dim        ← crm_cust_info, erp_cust_az12, erp_loc_a101
   gold.vw_product_dim         ← crm_prd_info, erp_px_cat_g1v2
   gold.vw_sales_fact          ← crm_sales_details, vw_product_dim, vw_customer_dim
===============================================================================
*/

USE KyinduDataWarehouse;
GO

IF OBJECT_ID('gold.vw_customer_dim', 'V') IS NOT NULL
    DROP VIEW gold.vw_customer_dim;
GO

CREATE VIEW gold.vw_customer_dim AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY customer_info.cst_id) AS customer_key
    ,customer_info.[cst_id] AS customer_id
    ,customer_info.[cst_key] AS customer_number
    ,customer_info.[cst_firstname] AS customer_firstname
    ,customer_info.[cst_lastname] AS customer_lastname
    ,customer_info.[cst_marital_status] AS customer_marital_status
    ,CASE WHEN customer_info.[cst_gndr] != 'n/a' THEN customer_info.[cst_gndr]
        ELSE COALESCE(customer_erp.[gen], 'n/a')
    END AS customer_gender
    ,customer_loc.cntry AS customer_country
    ,customer_erp.[bdate] AS customer_birthdate
    ,customer_info.[cst_create_date] AS customer_create_date
FROM [silver].[crm_cust_info] customer_info
LEFT JOIN [silver].[erp_cust_az12] customer_erp
ON customer_info.cst_key = customer_erp.cid
LEFT JOIN [silver].[erp_loc_a101] customer_loc
ON customer_info.cst_key = customer_loc.cid;
GO


-- =============================================================================
-- gold.vw_product_dim
-- =============================================================================

IF OBJECT_ID('gold.vw_product_dim', 'V') IS NOT NULL
    DROP VIEW gold.vw_product_dim;
GO

CREATE VIEW gold.vw_product_dim AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY product_info.prd_start_dt, product_info.prd_key) AS product_key
    ,product_info.[prd_id] AS product_id
    ,product_info.[prd_key] AS product_number
    ,product_info.[prd_nm] AS product_name
    ,product_info.[prd_line] AS product_line
    ,product_info.[cat_id] AS category_id
    ,product_category.[cat] AS category
    ,product_category.[subcat] AS subcategory
    ,product_info.[prd_cost] AS product_cost
    ,product_category.[maintenance] AS maintenance
    ,product_info.[prd_start_dt] AS product_start_date
    ,product_info.[prd_end_dt] AS product_end_date
FROM [silver].[crm_prd_info] product_info
LEFT JOIN [silver].[erp_px_cat_g1v2] product_category
  ON product_info.cat_id = product_category.id;
GO


-- =============================================================================
-- gold.vw_sales_fact
-- =============================================================================

IF OBJECT_ID('gold.vw_sales_fact', 'V') IS NOT NULL
    DROP VIEW gold.vw_sales_fact;
GO

CREATE VIEW gold.vw_sales_fact AS
SELECT 
    sales_details.[sls_ord_num] AS sales_order_number
    ,product_dim.[product_key]
    ,customer_dim.[customer_key]
    ,sales_details.[sls_order_dt] AS sales_order_date
    ,sales_details.[sls_ship_dt] AS sales_ship_date
    ,sales_details.[sls_due_dt] AS sales_due_date
    ,sales_details.[sls_sales] AS sales_amount
    ,sales_details.[sls_quantity] AS sales_quantity
    ,sales_details.[sls_price] AS sales_price
    ,sales_details.[dwh_load_date] AS dwh_load_date
FROM [silver].[crm_sales_details] sales_details
LEFT JOIN [gold].[vw_product_dim] product_dim
  ON sales_details.sls_prd_key = product_dim.product_number
 AND sales_details.sls_order_dt >= product_dim.product_start_date
 AND (sales_details.sls_order_dt <= product_dim.product_end_date OR product_dim.product_end_date IS NULL)
LEFT JOIN [gold].[vw_customer_dim] customer_dim
  ON sales_details.sls_cust_id = customer_dim.customer_id;
GO
