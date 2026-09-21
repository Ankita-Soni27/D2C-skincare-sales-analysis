/* ============================================================
   D2C Skincare Brand - Sales & Customer Analysis
   File   : 01_schema_and_load.sql
   Purpose: Create the database, tables and load the CSV files.
   Engine : Microsoft SQL Server (SSMS)

   HOW TO USE
   1. Run this file top to bottom in SSMS.
   2. Before running, change the file paths in the BULK INSERT
      section to the folder where you saved the /data CSVs.
      Example: 'C:\Projects\d2c-skincare-sales-analysis\data\D2C_Customers.csv'
   3. If BULK INSERT fails due to permissions, use the SSMS
      Import Wizard instead (right-click DB > Tasks > Import Flat File)
      and load into the *_staging tables below.

   NOTE ON DATES
   The CSV files store dates as dd-mm-yyyy text. They are loaded
   into staging tables as VARCHAR, then converted to the DATE type
   using CONVERT(date, value, 105). This keeps the analysis layer
   clean and lets you use real date functions.
   ============================================================ */

IF DB_ID('D2C_Skincare') IS NULL
    CREATE DATABASE D2C_Skincare;
GO

USE D2C_Skincare;
GO

/* ------------------------------------------------------------
   1. DROP EXISTING OBJECTS (safe to re-run this whole script)
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.Reviews', 'U')     IS NOT NULL DROP TABLE dbo.Reviews;
IF OBJECT_ID('dbo.Returns', 'U')     IS NOT NULL DROP TABLE dbo.Returns;
IF OBJECT_ID('dbo.Order_Items', 'U') IS NOT NULL DROP TABLE dbo.Order_Items;
IF OBJECT_ID('dbo.Orders', 'U')      IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products', 'U')    IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers', 'U')   IS NOT NULL DROP TABLE dbo.Customers;
GO

/* ------------------------------------------------------------
   2. DIMENSION TABLES
   ------------------------------------------------------------ */
CREATE TABLE dbo.Customers (
    customer_id         VARCHAR(10)  NOT NULL PRIMARY KEY,
    customer_name       VARCHAR(100) NULL,
    city                VARCHAR(50)  NULL,
    state               VARCHAR(50)  NULL,
    gender              VARCHAR(20)  NULL,
    age_group           VARCHAR(20)  NULL,
    signup_date         DATE         NULL,
    acquisition_channel VARCHAR(50)  NULL
);

CREATE TABLE dbo.Products (
    product_id     VARCHAR(10)   NOT NULL PRIMARY KEY,
    product_name   VARCHAR(150)  NULL,
    category       VARCHAR(50)   NULL,
    concern        VARCHAR(50)   NULL,
    skin_type      VARCHAR(50)   NULL,
    key_ingredient VARCHAR(100)  NULL,
    size           VARCHAR(20)   NULL,
    mrp            DECIMAL(10,2) NULL,
    cost_price     DECIMAL(10,2) NULL,
    stock_qty      INT           NULL,
    launch_date    DATE          NULL
);
GO

/* ------------------------------------------------------------
   3. FACT TABLES
   ------------------------------------------------------------ */
CREATE TABLE dbo.Orders (
    order_id        VARCHAR(10)   NOT NULL PRIMARY KEY,
    customer_id     VARCHAR(10)   NULL REFERENCES dbo.Customers(customer_id),
    order_date      DATE          NULL,
    order_status    VARCHAR(20)   NULL,
    payment_method  VARCHAR(30)   NULL,
    sales_channel   VARCHAR(30)   NULL,
    gross_amount    DECIMAL(12,2) NULL,   -- sum of item_total (already net of line discount)
    discount_amount DECIMAL(12,2) NULL,   -- value discounted off MRP
    shipping_fee    DECIMAL(10,2) NULL,
    final_amount    DECIMAL(12,2) NULL,   -- gross_amount + shipping_fee
    delivered_date  DATE          NULL
);

CREATE TABLE dbo.Order_Items (
    order_item_id VARCHAR(12)   NOT NULL PRIMARY KEY,
    order_id      VARCHAR(10)   NULL REFERENCES dbo.Orders(order_id),
    product_id    VARCHAR(10)   NULL REFERENCES dbo.Products(product_id),
    quantity      INT           NULL,
    unit_price    DECIMAL(10,2) NULL,
    discount_pct  DECIMAL(5,2)  NULL,
    item_total    DECIMAL(12,2) NULL
);

CREATE TABLE dbo.Returns (
    return_id     VARCHAR(10) NOT NULL PRIMARY KEY,
    order_id      VARCHAR(10) NULL REFERENCES dbo.Orders(order_id),
    product_id    VARCHAR(10) NULL REFERENCES dbo.Products(product_id),
    return_date   DATE        NULL,
    return_reason VARCHAR(60) NULL,
    refund_status VARCHAR(30) NULL
);

CREATE TABLE dbo.Reviews (
    review_id   VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(10) NULL REFERENCES dbo.Customers(customer_id),
    product_id  VARCHAR(10) NULL REFERENCES dbo.Products(product_id),
    order_id    VARCHAR(10) NULL REFERENCES dbo.Orders(order_id),
    rating      INT         NULL,
    review_date DATE        NULL
);
GO

/* ------------------------------------------------------------
   4. STAGING TABLES (all text, so dd-mm-yyyy dates load cleanly)
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.stg_Customers','U')   IS NOT NULL DROP TABLE dbo.stg_Customers;
IF OBJECT_ID('dbo.stg_Products','U')    IS NOT NULL DROP TABLE dbo.stg_Products;
IF OBJECT_ID('dbo.stg_Orders','U')      IS NOT NULL DROP TABLE dbo.stg_Orders;
IF OBJECT_ID('dbo.stg_Order_Items','U') IS NOT NULL DROP TABLE dbo.stg_Order_Items;
IF OBJECT_ID('dbo.stg_Returns','U')     IS NOT NULL DROP TABLE dbo.stg_Returns;
IF OBJECT_ID('dbo.stg_Reviews','U')     IS NOT NULL DROP TABLE dbo.stg_Reviews;

CREATE TABLE dbo.stg_Customers   (customer_id VARCHAR(20), customer_name VARCHAR(100), city VARCHAR(50), state VARCHAR(50), gender VARCHAR(20), age_group VARCHAR(20), signup_date VARCHAR(20), acquisition_channel VARCHAR(50));
CREATE TABLE dbo.stg_Products    (product_id VARCHAR(20), product_name VARCHAR(150), category VARCHAR(50), concern VARCHAR(50), skin_type VARCHAR(50), key_ingredient VARCHAR(100), size VARCHAR(20), mrp VARCHAR(20), cost_price VARCHAR(20), stock_qty VARCHAR(20), launch_date VARCHAR(20));
CREATE TABLE dbo.stg_Orders      (order_id VARCHAR(20), customer_id VARCHAR(20), order_date VARCHAR(20), order_status VARCHAR(20), payment_method VARCHAR(30), sales_channel VARCHAR(30), gross_amount VARCHAR(20), discount_amount VARCHAR(20), shipping_fee VARCHAR(20), final_amount VARCHAR(20), delivered_date VARCHAR(20));
CREATE TABLE dbo.stg_Order_Items (order_item_id VARCHAR(20), order_id VARCHAR(20), product_id VARCHAR(20), quantity VARCHAR(20), unit_price VARCHAR(20), discount_pct VARCHAR(20), item_total VARCHAR(20));
CREATE TABLE dbo.stg_Returns     (return_id VARCHAR(20), order_id VARCHAR(20), product_id VARCHAR(20), return_date VARCHAR(20), return_reason VARCHAR(60), refund_status VARCHAR(30));
CREATE TABLE dbo.stg_Reviews     (review_id VARCHAR(20), customer_id VARCHAR(20), product_id VARCHAR(20), order_id VARCHAR(20), rating VARCHAR(10), review_date VARCHAR(20));
GO

/* ------------------------------------------------------------
   5. LOAD CSVs  -->  CHANGE THE PATHS BELOW TO YOUR FOLDER
   ------------------------------------------------------------ */
BULK INSERT dbo.stg_Customers   FROM 'C:\Projects\d2c-skincare-sales-analysis\data\D2C_Customers.csv'   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
BULK INSERT dbo.stg_Products    FROM 'C:\Projects\d2c-skincare-sales-analysis\data\D2C_products.csv'    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
BULK INSERT dbo.stg_Orders      FROM 'C:\Projects\d2c-skincare-sales-analysis\data\D2C_orders.csv'      WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
BULK INSERT dbo.stg_Order_Items FROM 'C:\Projects\d2c-skincare-sales-analysis\data\D2C_Order_Items.csv' WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
BULK INSERT dbo.stg_Returns     FROM 'C:\Projects\d2c-skincare-sales-analysis\data\Returns.csv'         WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
BULK INSERT dbo.stg_Reviews     FROM 'C:\Projects\d2c-skincare-sales-analysis\data\Reviews.csv'         WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0d0a', TABLOCK);
GO

/* ------------------------------------------------------------
   6. TRANSFORM STAGING --> FINAL TABLES
      Dates converted with style 105 = dd-mm-yyyy
      Load order respects the foreign keys.
   ------------------------------------------------------------ */
INSERT INTO dbo.Customers
SELECT customer_id, customer_name, city, state, gender, age_group,
       TRY_CONVERT(date, NULLIF(signup_date,''), 105), acquisition_channel
FROM dbo.stg_Customers;

INSERT INTO dbo.Products
SELECT product_id, product_name, category, concern, skin_type, key_ingredient, size,
       TRY_CONVERT(decimal(10,2), mrp),
       TRY_CONVERT(decimal(10,2), cost_price),
       TRY_CONVERT(int, stock_qty),
       TRY_CONVERT(date, NULLIF(launch_date,''), 105)
FROM dbo.stg_Products;

INSERT INTO dbo.Orders
SELECT order_id, customer_id,
       TRY_CONVERT(date, NULLIF(order_date,''), 105),
       order_status, payment_method, sales_channel,
       TRY_CONVERT(decimal(12,2), gross_amount),
       TRY_CONVERT(decimal(12,2), discount_amount),
       TRY_CONVERT(decimal(10,2), shipping_fee),
       TRY_CONVERT(decimal(12,2), final_amount),
       TRY_CONVERT(date, NULLIF(delivered_date,''), 105)
FROM dbo.stg_Orders;

INSERT INTO dbo.Order_Items
SELECT order_item_id, order_id, product_id,
       TRY_CONVERT(int, quantity),
       TRY_CONVERT(decimal(10,2), unit_price),
       TRY_CONVERT(decimal(5,2), discount_pct),
       TRY_CONVERT(decimal(12,2), item_total)
FROM dbo.stg_Order_Items;

INSERT INTO dbo.Returns
SELECT return_id, order_id, product_id,
       TRY_CONVERT(date, NULLIF(return_date,''), 105),
       return_reason, refund_status
FROM dbo.stg_Returns;

INSERT INTO dbo.Reviews
SELECT review_id, customer_id, product_id, order_id,
       TRY_CONVERT(int, rating),
       TRY_CONVERT(date, NULLIF(review_date,''), 105)
FROM dbo.stg_Reviews;
GO

/* ------------------------------------------------------------
   7. ROW COUNT CHECK - expected values shown in comments
   ------------------------------------------------------------ */
SELECT 'Customers'   AS table_name, COUNT(*) AS row_count FROM dbo.Customers    -- 500
UNION ALL SELECT 'Products',   COUNT(*) FROM dbo.Products                       --  28
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders                         -- 1250
UNION ALL SELECT 'Order_Items',COUNT(*) FROM dbo.Order_Items                    -- 2042
UNION ALL SELECT 'Returns',    COUNT(*) FROM dbo.Returns                        --  79
UNION ALL SELECT 'Reviews',    COUNT(*) FROM dbo.Reviews;                       -- 494
GO

/* ------------------------------------------------------------
   8. DROP STAGING TABLES
   ------------------------------------------------------------ */
DROP TABLE dbo.stg_Customers, dbo.stg_Products, dbo.stg_Orders,
           dbo.stg_Order_Items, dbo.stg_Returns, dbo.stg_Reviews;
GO
