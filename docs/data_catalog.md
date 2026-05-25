# Data Warehouse Data Catalog (Gold Layer)

Welcome to the **KyinduDataWarehouse** Data Catalog. This document serves as the guide for business intelligence (BI) analysts, report developers, and business users to understand and query the reporting-ready views in the **Gold Schema**.

---

## 1. Medallion Architecture Overview

Our data warehouse is designed using the medallion architecture. Data flows from raw files to cleansed tables, and finally into the Gold Layer as dimensional models ready for business analysis:

```mermaid
graph TD
    subgraph Bronze [1. Bronze Layer (Raw Load)]
        b_crm_cust["bronze.crm_cust_info (CSV)"]
        b_crm_prd["bronze.crm_prd_info (CSV)"]
        b_crm_sales["bronze.crm_sales_details (CSV)"]
        b_erp_cust["bronze.erp_cust_az12 (CSV)"]
        b_erp_loc["bronze.erp_loc_a101 (CSV)"]
        b_erp_px["bronze.erp_px_cat_g1v2 (CSV)"]
    end
    subgraph Silver [2. Silver Layer (Clean & Standardize)]
        s_crm_cust["silver.crm_cust_info"]
        s_crm_prd["silver.crm_prd_info"]
        s_crm_sales["silver.crm_sales_details"]
        s_erp_cust["silver.erp_cust_az12"]
        s_erp_loc["silver.erp_loc_a101"]
        s_erp_px["silver.erp_px_cat_g1v2"]
    end
    subgraph Gold [3. Gold Layer (Dimensional Reporting)]
        g_cust_dim["gold.vw_customer_dim (Dimension)"]
        g_prd_dim["gold.vw_product_dim (Dimension - SCD 2)"]
        g_sales_fact["gold.vw_sales_fact (Fact)"]
    end

    b_crm_cust --> s_crm_cust
    b_crm_prd --> s_crm_prd
    b_crm_sales --> s_crm_sales
    b_erp_cust --> s_erp_cust
    b_erp_loc --> s_erp_loc
    b_erp_px --> s_erp_px

    s_crm_cust --> g_cust_dim
    s_erp_cust --> g_cust_dim
    s_erp_loc --> g_cust_dim

    s_crm_prd --> g_prd_dim
    s_erp_px --> g_prd_dim

    s_crm_sales --> g_sales_fact
    g_cust_dim --> g_sales_fact
    g_prd_dim --> g_sales_fact
```

---

## 2. Gold Views Directory

### A. Customer Dimension (`gold.vw_customer_dim`)
Contains consolidated and standardized customer profile data. It merges CRM records with ERP birth dates, genders, and addresses.

| Column Name               | Data Type      | Key Type      | Business Rule / Description                                                  | Example Value |
| :------------------------ | :------------- | :------------ | :--------------------------------------------------------------------------- | :------------ |
| **`customer_key`**        | `BIGINT`       | Surrogate Key | Auto-generated row number to uniquely identify each customer in Gold.         | `1`           |
| `customer_id`             | `INT`          | Natural Key   | The raw unique ID assigned to the customer in the CRM system.                | `11000`       |
| `customer_number`         | `NVARCHAR(50)` | Business Key  | Alphanumeric key used to join CRM and ERP records (e.g. `AW00011000`).        | `'AW00011000'`|
| `customer_firstname`      | `NVARCHAR(50)` | Attribute     | Cleaned first name with whitespace removed.                                   | `'Jon'`       |
| `customer_lastname`       | `NVARCHAR(50)` | Attribute     | Cleaned last name with whitespace removed.                                    | `'Yang'`      |
| `customer_marital_status` | `NVARCHAR(50)` | Attribute     | Standardized marital status (e.g., `'Married'`, `'Single'`, `'n/a'`).         | `'Married'`   |
| `customer_gender`         | `NVARCHAR(50)` | Attribute     | Standardized gender. Prioritizes CRM data; falls back to ERP if CRM is empty. | `'Male'`      |
| `customer_country`        | `NVARCHAR(50)` | Attribute     | Standardized country name (e.g., `'Germany'`, `'United States'`, etc.).       | `'Australia'` |
| `customer_birthdate`      | `DATE`         | Attribute     | Date of birth sourced from ERP (future dates default to `NULL`).              | `'1971-10-06'`|
| `customer_create_date`    | `DATE`         | Temporal      | Date the customer record was first created.                                   | `'2025-10-06'`|

---

### B. Product Dimension (`gold.vw_product_dim`)
A Slowly Changing Dimension (SCD Type 2) tracking historical changes to product details. Multiple rows can exist for a single product number if its attributes (e.g. cost) changed over time.

| Column Name          | Data Type      | Key Type      | Business Rule / Description                                                  | Example Value  |
| :------------------- | :------------- | :------------ | :--------------------------------------------------------------------------- | :------------- |
| **`product_key`**     | `BIGINT`       | Surrogate Key | Auto-generated row number. Uniquely identifies a specific product version.  | `3`            |
| `product_id`          | `INT`          | Natural Key   | The raw unique ID assigned to the product in the CRM system.                | `348`          |
| `product_number`      | `NVARCHAR(50)` | Business Key  | Alphanumeric product identifier (e.g., `'BK-M82B-38'`).                      | `'BK-M82B-38'` |
| `product_name`        | `NVARCHAR(50)` | Attribute     | Name of the product.                                                         | `'Mtn-100-38'` |
| `product_line`        | `NVARCHAR(50)` | Attribute     | Standardized line: `'Mountain'`, `'Road'`, `'Other Sales'`, etc.             | `'Mountain'`   |
| `category_id`         | `NVARCHAR(50)` | Attribute     | Category code, cleaned with hyphens replaced by underscores.                 | `'BI_MB'`      |
| `category`            | `NVARCHAR(50)` | Attribute     | Standardized product category (e.g., `'Bikes'`).                             | `'Bikes'`      |
| `subcategory`         | `NVARCHAR(50)` | Attribute     | Standardized product subcategory (e.g., `'Mountain Bikes'`).                 | `'Mtn Bikes'`  |
| `product_cost`        | `INT`          | Metric        | Cost of the product (defaults to `0` if missing).                            | `1898`         |
| `maintenance`         | `NVARCHAR(50)` | Attribute     | Indicates if the product requires maintenance (`'Yes'`/`'No'`).               | `'Yes'`        |
| `product_start_date`  | `DATE`         | SCD Timeline  | Date when version became active. Oldest version defaults to `'1900-01-01'`.   | `'1900-01-01'` |
| `product_end_date`    | `DATE`         | SCD Timeline  | Date when version ceased to be active (`NULL` indicates current version).    | `NULL`         |

---

### C. Sales Fact View (`gold.vw_sales_fact`)
Contains all sales transactions. It is mapped to the customer and product dimension surrogate keys (`customer_key` and `product_key`) active at the time of purchase.

| Column Name          | Data Type      | Key Type   | Business Rule / Description                                                  | Example Value |
| :------------------- | :------------- | :--------- | :--------------------------------------------------------------------------- | :------------ |
| `sales_order_number`  | `NVARCHAR(50)` | Attribute  | Unique identifier for the sales order transaction.                          | `'SO43697'`   |
| **`product_key`**     | `BIGINT`       | Foreign Key| Links to `gold.vw_product_dim.product_key`. Resolved historically.           | `32`          |
| **`customer_key`**    | `BIGINT`       | Foreign Key| Links to `gold.vw_customer_dim.customer_key`.                                | `10769`       |
| `sales_order_date`    | `DATE`         | Temporal   | Date the order was placed.                                                   | `'2010-12-29'`|
| `sales_ship_date`     | `DATE`         | Temporal   | Date the order was shipped.                                                  | `'2011-01-05'`|
| `sales_due_date`      | `DATE`         | Temporal   | Date the order payment/shipment is due.                                      | `'2011-01-10'`|
| `sales_amount`        | `INT`          | Metric     | Financial sales amount (quantity * price).                                   | `3578`        |
| `sales_quantity`      | `INT`          | Metric     | Quantity of products ordered.                                                | `1`           |
| `sales_price`         | `INT`          | Metric     | Unit price of the product.                                                   | `3578`        |
| `dwh_load_date`       | `DATETIME2`    | Audit      | Timestamp showing when this transaction row was loaded.                      | `'2026-05-25'`|

---

## 3. Sample BI Starter Queries

Here are standard reporting SQL templates to help you query the star schema.

### Query 1: Total Sales Revenue and Units Sold by Country
```sql
SELECT 
    c.customer_country AS Country
    ,SUM(s.sales_amount) AS Total_Revenue
    ,SUM(s.sales_quantity) AS Total_Units_Sold
FROM gold.vw_sales_fact s
INNER JOIN gold.vw_customer_dim c 
  ON s.customer_key = c.customer_key
GROUP BY c.customer_country
ORDER BY Total_Revenue DESC;
```

### Query 2: Product Sales Performance by Category and Line
```sql
SELECT 
    p.category AS Category
    ,p.subcategory AS Subcategory
    ,p.product_line AS Product_Line
    ,SUM(s.sales_amount) AS Total_Revenue
    ,COUNT(DISTINCT s.sales_order_number) AS Total_Orders
FROM gold.vw_sales_fact s
INNER JOIN gold.vw_product_dim p 
  ON s.product_key = p.product_key
GROUP BY p.category, p.subcategory, p.product_line
ORDER BY Total_Revenue DESC;
```
