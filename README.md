# D2C Skincare Brand — Sales & Customer Analysis (SQL)

End-to-end SQL analysis of a direct-to-consumer skincare brand: 1,250 orders, 500 customers, 28 SKUs and 494 product reviews across six related tables. The goal is to answer the questions a founder or category manager would actually ask — what sells, what makes money, what gets sent back, and which customers come back.

**Tools:** Microsoft SQL Server (SSMS) · Power BI

---

## Data source

- **Dataset:** Public synthetic dataset from Kaggle.
- **Synthetic data.** The records are not from a real company. The findings below describe this dataset only and are not real business results. The project is meant to show SQL, data modelling and analysis skills.
- **Period covered:** orders from 2024 and 2025.

---

## Repository structure

```
d2c-skincare-sales-analysis/
├── data/                        # Six source CSV files
│   ├── D2C_Customers.csv        # 500 rows
│   ├── D2C_products.csv         #  28 rows
│   ├── D2C_orders.csv           # 1,250 rows
│   ├── D2C_Order_Items.csv      # 2,042 rows
│   ├── Returns.csv              #  79 rows
│   └── Reviews.csv              # 494 rows
├── sql/
│   ├── 01_schema_and_load.sql   # Create DB, tables, keys; load and clean the CSVs
│   └── 02_analysis.sql          # 15 business questions answered in SQL
└── README.md
```

---

## Data model

A star schema with two dimensions and four fact tables.

| Table | Grain | Key columns |
|---|---|---|
| `Customers` | One row per customer | `customer_id`, city, state, age group, acquisition channel |
| `Products` | One row per SKU | `product_id`, category, concern, skin type, MRP, cost price |
| `Orders` | One row per order | `order_id`, `customer_id`, status, channel, final amount |
| `Order_Items` | One row per product in an order | `order_item_id`, `order_id`, `product_id`, quantity, discount |
| `Returns` | One row per returned item | `return_id`, `order_id`, `product_id`, reason |
| `Reviews` | One row per review | `review_id`, `customer_id`, `product_id`, rating |

`Orders` → `Order_Items` → `Products` is the main revenue path. `Returns` links to `Products` and `Orders`; in the Power BI model the `Returns` → `Orders` link is removed to avoid an ambiguous circular relationship.

---

## Business rules applied

These decisions shape every number in the analysis:

- **Revenue counts only delivered orders.** Cancelled, Returned and In Transit orders hold about 18% of total item value. Counting them would overstate every category and product figure.
- **Two revenue definitions.** `Orders.final_amount` includes the shipping fee; `Order_Items.item_total` is product value only. Order-level and product-level totals therefore do not match, and that is intentional.
- **Profit is measured against the actual selling price**, not MRP. Products sell below MRP after discounts, so an MRP-based margin is inflated.
- **Return rate is returns ÷ units sold**, not a product's share of all returns. Share of returns simply flags bestsellers.

---

## Key findings

| Metric | Value |
|---|---|
| Delivered orders | 1,020 |
| Delivered revenue (order level, includes shipping) | ₹9.82 lakh |
| Delivered product revenue (item level, excludes shipping) | ₹9.58 lakh |
| Average order value | ₹963 |
| Repeat buyer rate | 68% (299 of 438 customers with a delivered order bought 2+ times) |
| Average product rating | 3.91 / 5 |
| Cancelled and Returned orders | about 13% of total item value |

**1. Serum is the business.** Serums generate ₹4.31 lakh — about 45% of delivered product revenue, more than the next three categories (Moisturizer, Sunscreen, Hair Care) combined. Concentration this high is a risk as well as a strength: one serum supply issue would take out nearly half of revenue.

**2. High revenue and high margin are not the same products.** Serum earns a 50.5% gross margin, the second lowest of nine categories after Hair Care (49.8%). Lip Care (59.1%), Cleanser (55.9%) and Toner (55.1%) earn more per rupee sold but stay small. The gap is not explained by deeper discounts: serums average a 9.5% discount, in line with other categories (9.0%–10.3%), so the lower margin more likely comes from cost price.

**3. Returns are a product problem, not a logistics problem.** Skin irritation is the single largest return reason (28 of 79 returns, 35%), ahead of late delivery (16) and damaged packaging (13). Courier fixes would not move the number much; ingredient or claims testing would.

**4. Retention is strong in this dataset.** 68% of customers with a delivered order bought again. For a D2C brand this would be the most valuable asset, and it would argue for spending on repeat-purchase incentives over new-customer acquisition.

**5. Acquisition is concentrated in two channels.** Google Search (148 customers) and Instagram (145) together bring about 59% of the customer base. YouTube (78), Website Direct (70) and Referral (59) trail well behind.

---

## How to run it

1. Clone or download this repository.
2. Open `sql/01_schema_and_load.sql` in SSMS.
3. Change the six file paths in the `BULK INSERT` block to wherever you saved the `data` folder.
4. Run the whole script. It creates the database, builds the tables with primary and foreign keys, loads the CSVs through staging tables, converts `dd-mm-yyyy` text into proper `DATE` values, and prints a row-count check.
5. Run `sql/02_analysis.sql` query by query.

---

## SQL techniques used

Joins across six tables · CTEs · window functions (`SUM() OVER()`) · conditional aggregation with `CASE` · date formatting and conversion · staging-to-production load pattern · primary and foreign key constraints · `TRY_CONVERT` for safe type casting.

---

## Limitations

- The data is synthetic, so patterns such as the repeat rate and return reasons reflect how the dataset was generated.
- Margin uses product cost price only. Shipping, returns handling and marketing costs are not included.
- Two years of orders is too short to measure seasonality reliably.

---

## Possible next steps

- RFM segmentation to score customers by recency, frequency and monetary value
- Cohort retention curves by signup month
- Contribution margin after returns and shipping cost, not just gross margin
