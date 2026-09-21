/* ============================================================
   D2C Skincare Brand - Sales & Customer Analysis
   File   : 02_analysis.sql
   Author : Ankita
   Engine : Microsoft SQL Server (SSMS)
   Run 01_schema_and_load.sql first.

   DEFINITIONS USED THROUGHOUT
   - "Revenue" at order level  = Orders.final_amount (product value + shipping fee)
   - "Revenue" at product level = Order_Items.item_total (product value only,
     already net of the line-level discount)
   - Only orders with order_status = 'Delivered' count as revenue.
     Cancelled, Returned and In Transit orders are excluded everywhere.
     This matters: they hold about 18% of total item value, so leaving
     them in would overstate every product and category number.
   ============================================================ */

USE D2C_Skincare;
GO

/* ------------------------------------------------------------
   1. Headline KPIs: orders, revenue, average order value
   Q: How big is the business and what does a typical order look like?
   ------------------------------------------------------------ */
SELECT
    COUNT(order_id)    AS total_orders,
    SUM(final_amount)  AS total_revenue,
    AVG(final_amount)  AS avg_order_value
FROM dbo.Orders
WHERE order_status = 'Delivered';
GO

/* ------------------------------------------------------------
   2. Monthly revenue trend
   Q: Is revenue growing, flat or seasonal?
   ------------------------------------------------------------ */
SELECT
    FORMAT(order_date, 'yyyy-MM') AS order_month,
    COUNT(order_id)               AS total_orders,
    SUM(final_amount)             AS monthly_revenue
FROM dbo.Orders
WHERE order_status = 'Delivered'
GROUP BY FORMAT(order_date, 'yyyy-MM')
ORDER BY order_month;
GO

/* ------------------------------------------------------------
   3. Revenue by product category
   Q: Which categories carry the business?
   ------------------------------------------------------------ */
SELECT
    p.category,
    SUM(oi.quantity)                    AS units_sold,
    SUM(oi.item_total)                  AS category_revenue,
    SUM(oi.item_total) * 100.0
        / SUM(SUM(oi.item_total)) OVER() AS pct_of_revenue
FROM dbo.Order_Items oi
JOIN dbo.Orders   o ON oi.order_id   = o.order_id
JOIN dbo.Products p ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY category_revenue DESC;
GO

/* ------------------------------------------------------------
   4. Top 10 products by revenue
   Q: Which individual SKUs should never go out of stock?
   ------------------------------------------------------------ */
SELECT TOP 10
    p.product_name,
    p.category,
    SUM(oi.quantity)   AS units_sold,
    SUM(oi.item_total) AS product_revenue
FROM dbo.Order_Items oi
JOIN dbo.Orders   o ON oi.order_id   = o.order_id
JOIN dbo.Products p ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_name, p.category
ORDER BY product_revenue DESC;
GO

/* ------------------------------------------------------------
   5. Discount impact
   Q: Do deeper discounts actually buy more volume?
   ------------------------------------------------------------ */
SELECT
    oi.discount_pct,
    COUNT(oi.order_item_id) AS line_items,
    SUM(oi.quantity)        AS units_sold,
    SUM(oi.item_total)      AS total_revenue,
    AVG(oi.item_total)      AS avg_line_value
FROM dbo.Order_Items oi
JOIN dbo.Orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY oi.discount_pct
ORDER BY oi.discount_pct;
GO

/* ------------------------------------------------------------
   6. Revenue by acquisition channel
   Q: Which channel brings customers who actually spend?
   ------------------------------------------------------------ */
SELECT
    c.acquisition_channel,
    COUNT(DISTINCT c.customer_id)                     AS buying_customers,
    COUNT(o.order_id)                                 AS total_orders,
    SUM(o.final_amount)                               AS total_revenue,
    SUM(o.final_amount) / COUNT(DISTINCT c.customer_id) AS revenue_per_customer
FROM dbo.Customers c
JOIN dbo.Orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.acquisition_channel
ORDER BY total_revenue DESC;
GO

/* ------------------------------------------------------------
   7. Top 10 cities by order volume
   Q: Where is demand concentrated?
   ------------------------------------------------------------ */
SELECT TOP 10
    c.city,
    c.state,
    COUNT(o.order_id)   AS total_orders,
    SUM(o.final_amount) AS total_revenue
FROM dbo.Customers c
JOIN dbo.Orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city, c.state
ORDER BY total_orders DESC;
GO

/* ------------------------------------------------------------
   8. Repeat vs one-time buyers
   Q: Is the brand retaining customers or constantly re-buying traffic?
   ------------------------------------------------------------ */
WITH buyer_summary AS (
    SELECT
        customer_id,
        CASE WHEN COUNT(order_id) > 1 THEN 'Repeat Buyer'
             ELSE 'One-Time Buyer' END AS purchase_type
    FROM dbo.Orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    purchase_type,
    COUNT(*)                          AS customer_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS pct_of_customers
FROM buyer_summary
GROUP BY purchase_type;
GO

/* ------------------------------------------------------------
   9. Return rate by product
   Q: Which products are returned most often relative to how much they sell?
   Note: this is a true rate (returns / units sold), not each product's
   share of all returns. Share of returns rewards bestsellers unfairly.
   ------------------------------------------------------------ */
WITH sold AS (
    SELECT oi.product_id, SUM(oi.quantity) AS units_sold
    FROM dbo.Order_Items oi
    JOIN dbo.Orders o ON oi.order_id = o.order_id
    WHERE o.order_status IN ('Delivered', 'Returned')
    GROUP BY oi.product_id
),
returned AS (
    SELECT product_id, COUNT(return_id) AS total_returns
    FROM dbo.Returns
    GROUP BY product_id
)
SELECT
    p.product_name,
    p.category,
    s.units_sold,
    ISNULL(r.total_returns, 0) AS total_returns,
    ISNULL(r.total_returns, 0) * 100.0 / s.units_sold AS return_rate_pct
FROM sold s
JOIN dbo.Products p ON s.product_id = p.product_id
LEFT JOIN returned r ON s.product_id = r.product_id
WHERE s.units_sold >= 20                -- ignore low-volume noise
ORDER BY return_rate_pct DESC;
GO

/* ------------------------------------------------------------
   10. Return reasons
   Q: Is the problem the product, the courier or the packaging?
   ------------------------------------------------------------ */
SELECT
    return_reason,
    COUNT(return_id)                          AS total_returns,
    COUNT(return_id) * 100.0 / SUM(COUNT(return_id)) OVER() AS pct_of_returns
FROM dbo.Returns
GROUP BY return_reason
ORDER BY total_returns DESC;
GO

/* ------------------------------------------------------------
   11. Average rating by category
   Q: Where is customer satisfaction weakest?
   ------------------------------------------------------------ */
SELECT
    p.category,
    COUNT(rv.review_id)             AS total_reviews,
    AVG(CAST(rv.rating AS FLOAT))   AS avg_rating,
    SUM(CASE WHEN rv.rating <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(rv.review_id)       AS pct_low_ratings
FROM dbo.Reviews rv
JOIN dbo.Products p ON rv.product_id = p.product_id
GROUP BY p.category
ORDER BY avg_rating DESC;
GO

/* ------------------------------------------------------------
   12. Gross profit by product
   Q: Which products make money, not just revenue?
   Note: profit is measured against actual selling price (item_total),
   not MRP. Using MRP ignores every discount given and overstates profit.
   ------------------------------------------------------------ */
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity)                                       AS units_sold,
    SUM(oi.item_total)                                     AS net_revenue,
    SUM(oi.quantity * p.cost_price)                        AS total_cost,
    SUM(oi.item_total) - SUM(oi.quantity * p.cost_price)   AS gross_profit,
    (SUM(oi.item_total) - SUM(oi.quantity * p.cost_price)) * 100.0
        / SUM(oi.item_total)                               AS gross_margin_pct
FROM dbo.Products p
JOIN dbo.Order_Items oi ON p.product_id = oi.product_id
JOIN dbo.Orders o       ON oi.order_id  = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_name, p.category
ORDER BY gross_profit DESC;
GO

/* ------------------------------------------------------------
   13. Sales channel performance
   Q: App, website or marketplace - where is the money?
   ------------------------------------------------------------ */
SELECT
    sales_channel,
    COUNT(order_id)   AS total_orders,
    SUM(final_amount) AS total_revenue,
    AVG(final_amount) AS avg_order_value
FROM dbo.Orders
WHERE order_status = 'Delivered'
GROUP BY sales_channel
ORDER BY total_revenue DESC;
GO

/* ------------------------------------------------------------
   14. Order status funnel
   Q: How much revenue leaks to cancellations and returns?
   ------------------------------------------------------------ */
SELECT
    order_status,
    COUNT(order_id)                          AS total_orders,
    SUM(final_amount)                        AS order_value,
    SUM(final_amount) * 100.0 / SUM(SUM(final_amount)) OVER() AS pct_of_value
FROM dbo.Orders
GROUP BY order_status
ORDER BY order_value DESC;
GO

/* ------------------------------------------------------------
   15. Monthly new vs repeat customers
   Q: Is growth coming from new customers or from the existing base?
   ------------------------------------------------------------ */
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM dbo.Orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    FORMAT(o.order_date, 'yyyy-MM') AS order_month,
    SUM(CASE WHEN FORMAT(o.order_date,'yyyy-MM') = FORMAT(f.first_order_date,'yyyy-MM')
             THEN 1 ELSE 0 END)     AS new_customer_orders,
    SUM(CASE WHEN FORMAT(o.order_date,'yyyy-MM') > FORMAT(f.first_order_date,'yyyy-MM')
             THEN 1 ELSE 0 END)     AS repeat_customer_orders,
    SUM(o.final_amount)             AS monthly_revenue
FROM dbo.Orders o
JOIN first_order f ON o.customer_id = f.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY FORMAT(o.order_date, 'yyyy-MM')
ORDER BY order_month;
GO
