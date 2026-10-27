# E-Commerce Sales & Customer Behavior Analysis (Olist, Brazil)

An end-to-end data analysis of **~100,000 real orders** from Olist, Brazil's largest department-store marketplace,
covering **data cleaning, SQL analysis, Python exploratory analysis, customer segmentation, and an interactive dashboard.**

**Tools:** Python (Pandas, Matplotlib, Seaborn) · SQL (PostgreSQL / DuckDB) · Power BI · Jupyter · Git

---

## Business problem

Olist connects small sellers to customers across Brazil. Revenue more than doubled in a year, but growth stalled in 2018.
Leadership wants to know:

1. What is driving revenue, and why has growth flattened?
2. How much do delivery problems hurt customer satisfaction?
3. Which regions, categories and sellers need attention?
4. Do customers come back, and which customers should marketing target?

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle):
real, anonymised orders placed between September 2016 and October 2018, spread across **9 related tables**.
Eight are used here (orders, customers, order items, payments, reviews, products, sellers, category translation);
the geolocation table isn't needed because the analysis is done at state level.

| | |
|---|---|
| Orders | 99,441 (96,478 delivered) |
| Customers | 93,358 unique buyers |
| Sellers | 3,095 |
| Products | 32,951 across 74 categories |
| Revenue analysed | R$ 15.4 million |

---

## Key insights

### 1. Revenue grew 143% year over year, then plateaued
Jan-Aug 2018 revenue was **R$8.45M vs R$3.47M** for the same months of 2017. But monthly revenue flattened at
~R$1.0-1.1M through 2018. **Black Friday 2017** produced the busiest day in the data (1,147 orders, ~7x normal).

![Monthly revenue](images/01_monthly_revenue_trend.png)

### 2. Late deliveries are the biggest driver of bad reviews
Only **6.8%** of orders arrive late, but they account for **32.5% of all 1-2 star reviews**. On-time orders average
**4.29 stars**; orders 4+ days late average about **2 stars**.

![Review score by delivery delay](images/03_review_score_by_delivery_delay.png)

### 3. Customers accept slow delivery, but not broken promises
Northeast customers wait **20 days** on average (vs 8.8 in São Paulo) and are late **almost 3x as often**.
Across states, the late rate is strongly linked to review scores (**correlation -0.88**). Amazonas and Amapá wait
26+ days but are rarely late, and their reviews stay high. **Rio de Janeiro, the #2 market (13% of orders), is late
12.1% of the time** and has one of the lowest average reviews (3.97).

![Delivery vs reviews by state](images/04_delivery_vs_reviews_by_state.png)

### 4. Almost no one comes back
Only **3.0% of customers ever placed a second order** (2.2% excluding same-day split orders), and they bring just
5.6% of revenue. Fewer than **1 in 100** new customers order again in any later month. With ~6,400 new customers a month and
no retention, revenue can only grow as fast as acquisition, which explains the 2018 plateau.

![Cohort retention](images/09_cohort_retention_heatmap.png)

### 5. Two customer segments hold 56% of revenue
RFM segmentation shows **"Promising"** customers (recent, one high-value order, avg R$302) hold 28.4% of revenue and
**"Lost High-Value"** customers (similar spend, inactive 9+ months) hold another 27.3%.

![RFM segments](images/08_rfm_segments.png)

### 6. Other findings
- **Category concentration:** 8 of 74 categories generate half of revenue; health & beauty leads (9.2%).
- **Office furniture** is the weakest large category (3.64 stars, 20.6-day delivery, freight = 25% of price).
  It scores poorly even when on time, so the issue goes beyond logistics.
- **Installments drive basket size:** 68% of credit-card orders use installments; 7-10 installment orders average
  R$333 vs R$101 for single payments.
- **Seller dependency:** the top 10% of sellers generate **66% of revenue**.

| ![Categories](images/02_top_categories_revenue.png) | ![Sellers](images/06_seller_concentration.png) |
|---|---|
| ![Payments](images/05_payment_behaviour.png) | ![Day and hour](images/07_orders_by_day_and_hour.png) |

---

## Recommendations

| # | Recommendation | Based on |
|---|---|---|
| 1 | **Set realistic delivery estimates by region**, especially RJ and the Northeast, and hold carriers to them. Meeting the promise matters more than speed. | Insights 2-3 |
| 2 | **Add logistics capacity before peaks** (Black Friday, Feb-Mar), when late rates jumped to 12-19%. | Insight 2 |
| 3 | **Launch a second-purchase programme** for "Promising" customers within 30-60 days of their first order. | Insights 4-5 |
| 4 | **Run a win-back campaign** for the 13,700 "Lost High-Value" customers. | Insight 5 |
| 5 | **Review office-furniture sellers** for product quality and packaging, not just shipping. | Insight 6 |
| 6 | **Create a key-account programme** for the top 300 sellers to reduce dependency risk. | Insight 6 |
| 7 | **Promote interest-free installments** on high-ticket categories to grow basket size. | Insight 6 |

---

## Approach

1. **Data cleaning** ([notebook 01](notebooks/01_data_cleaning.ipynb)): profiled all tables, logged 13 data-quality
   issues and the decision taken for each ([log](data/processed/data_quality_log.csv) is regenerated when you run it).
   Key catches:
   - `customer_id` is generated **per order**, so the real customer is `customer_unique_id`. Using the wrong column
     would show a 0% repeat rate.
   - Zip codes must be read as text (leading zeros).
   - Some orders have multiple reviews (kept the latest).
   - Two categories had no English translation.
   - Sparse months at both ends were excluded from trend analysis.
2. **SQL analysis** ([01_schema.sql](sql/01_schema.sql), [02_business_questions.sql](sql/02_business_questions.sql)):
   relational schema with primary/foreign keys, cleaning views, and 15 business queries using JOINs, CTEs, `FILTER`,
   `CASE`, and window functions (`LAG`, `RANK`, `ROW_NUMBER`, `NTILE`, running totals).
   [See all results](sql/query_results.md). Every SQL result was cross-checked against the Python results.
3. **Exploratory analysis** ([notebook 02](notebooks/02_exploratory_analysis.ipynb)): sales trends, categories,
   delivery vs satisfaction, regional performance, payments, seller concentration, and time-of-day patterns.
4. **Customer analytics** ([notebook 03](notebooks/03_customer_analytics_rfm_cohort.ipynb)): repeat-purchase analysis,
   RFM segmentation with an action plan per segment, and monthly cohort retention.
5. **Dashboard** ([build guide](dashboard/POWER_BI_GUIDE.md)): 3-page Power BI report with a star-schema model and
   DAX measures (YoY, MoM, repeat rate, late-delivery impact).

**Metric definitions:**
- **Revenue** = item price + freight on delivered orders.
- **Late** = delivered on a calendar day after the estimated date shown to the customer.
- **Customer** = `customer_unique_id`.

---

## Repository structure

```
olist-ecommerce-analysis/
├── README.md
├── requirements.txt
├── data/
│   ├── raw/                 # 9 Olist CSVs (download from Kaggle; not committed)
│   └── processed/           # clean tables created by the notebooks
├── notebooks/
│   ├── 01_data_cleaning.ipynb
│   ├── 02_exploratory_analysis.ipynb
│   └── 03_customer_analytics_rfm_cohort.ipynb
├── sql/
│   ├── 01_schema.sql              # tables, keys, data load, cleaning views
│   ├── 02_business_questions.sql  # 15 business queries
│   ├── run_queries.py             # runs all SQL in DuckDB (no server needed)
│   └── query_results.md           # output of every query
├── dashboard/
│   └── POWER_BI_GUIDE.md
└── images/                  # charts used in this README
```

## How to run

```bash
git clone https://github.com/<your-username>/olist-ecommerce-analysis.git
cd olist-ecommerce-analysis
pip install -r requirements.txt
```

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and unzip the CSVs
   into `data/raw/` (see [data/raw/README.md](data/raw/README.md)).
2. Run the notebooks in order: `01` → `02` → `03`.
3. Run the SQL: `python sql/run_queries.py` (or load `sql/01_schema.sql` into PostgreSQL with `psql`).
4. Build the dashboard with [dashboard/POWER_BI_GUIDE.md](dashboard/POWER_BI_GUIDE.md).

## Limitations & next steps

- The data ends in 2018 and covers one marketplace, so findings describe that period.
- Review scores show correlation, not proof of causation. An A/B test on delivery estimates would confirm the effect.
- Next steps:
  - Predict which customers are likely to return (classification model).
  - Use the geolocation table to measure seller-to-customer distance.
  - Analyse review text with NLP.

---

**Author:** [Gowra Sreevarshini] · [LinkedIn](https://www.linkedin.com/in/sreevarshini-gowra-304b95325/) · [your.email@example.com](sreevarshinigowra@gmail.com)
