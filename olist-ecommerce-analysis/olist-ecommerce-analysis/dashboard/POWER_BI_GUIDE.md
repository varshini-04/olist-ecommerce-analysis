# Power BI Dashboard: Build Guide

This guide builds a 3-page interactive dashboard from the clean tables produced by `notebooks/01_data_cleaning.ipynb`
and `notebooks/03_customer_analytics_rfm_cohort.ipynb`. Expected build time: 3-5 hours the first time.

Power BI Desktop is free (Windows): https://powerbi.microsoft.com/desktop
On a Mac, use Tableau Public (free) and follow the same page plan.

---

## Step 1. Load the data

**Home → Get data → Text/CSV**, and load these three files from `data/processed/`:

| File | Rows | One row per |
|---|---|---|
| `fact_orders.csv` | 99,441 | order |
| `fact_order_items.csv` | 112,650 | item sold |
| `customer_segments.csv` | 93,358 | customer (RFM segment) |

In **Power Query (Transform data)**, check the column types:

- `purchase_date` → **Date**
- `order_purchase_timestamp`, `order_delivered_customer_date`, `order_estimated_delivery_date` → **Date/Time**
- `is_delivered`, `in_trend_window` → **True/False**
- `is_late` → **Decimal number** (1 = late, 0 = on time, blank = not delivered)
- `order_value`, `product_value`, `freight_value`, `payment_value`, `item_value`, `price`, `monetary` → **Decimal number**
- `customer_zip_code_prefix` is not used, so leave it as text if present

Click **Close & Apply**.

## Step 2. Create a Date table

**Modeling → New table**:

```dax
Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2016, 9, 1 ), DATE ( 2018, 10, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month Number", MONTH ( [Date] ),
    "Month Start", DATE ( YEAR ( [Date] ), MONTH ( [Date] ), 1 ),
    "Month", FORMAT ( [Date], "MMM yyyy" ),
    "Weekday", FORMAT ( [Date], "dddd" ),
    "Weekday Number", WEEKDAY ( [Date], 2 )
)
```

Then: select the table → **Table tools → Mark as date table** → choose `Date`.
Select the `Month` column → **Sort by column → Month Start**. Select `Weekday` → **Sort by column → Weekday Number**.

## Step 3. Relationships (Model view)

| From (one side) | To (many side) | Direction |
|---|---|---|
| `Date[Date]` | `fact_orders[purchase_date]` | Single |
| `fact_orders[order_id]` | `fact_order_items[order_id]` | Single |
| `customer_segments[customer_unique_id]` | `fact_orders[customer_unique_id]` | Single |

This is a simple star-style model: filters flow from Date and Customer Segments into Orders, and from Orders into Items.

## Step 4. Helper columns

In `fact_orders`, select `delivery_status` → **Sort by column → delivery_status_order** (so "On time" comes first).

Add two calculated columns to `fact_orders` for the installments chart:

```dax
Installment Group =
SWITCH (
    TRUE (),
    fact_orders[payment_installments] <= 1, "1 (full)",
    fact_orders[payment_installments] <= 3, "2-3",
    fact_orders[payment_installments] <= 6, "4-6",
    fact_orders[payment_installments] <= 10, "7-10",
    "11+"
)
```

```dax
Installment Group Order =
SWITCH (
    TRUE (),
    fact_orders[payment_installments] <= 1, 1,
    fact_orders[payment_installments] <= 3, 2,
    fact_orders[payment_installments] <= 6, 3,
    fact_orders[payment_installments] <= 10, 4,
    5
)
```

Sort `Installment Group` by `Installment Group Order`.

## Step 5. Measures

Create an empty table to hold measures (**Home → Enter data**, name it `_Measures`), then add each measure with
**New measure**. Format percentages as %, money as currency (R$).

```dax
Revenue =
CALCULATE ( SUM ( fact_orders[order_value] ), fact_orders[is_delivered] = TRUE () )

Delivered Orders =
CALCULATE ( COUNTROWS ( fact_orders ), fact_orders[is_delivered] = TRUE () )

Customers =
CALCULATE ( DISTINCTCOUNT ( fact_orders[customer_unique_id] ), fact_orders[is_delivered] = TRUE () )

Avg Order Value =
DIVIDE ( [Revenue], [Delivered Orders] )

Avg Review Score =
CALCULATE ( AVERAGE ( fact_orders[review_score] ), fact_orders[is_delivered] = TRUE () )

Avg Delivery Days =
CALCULATE ( AVERAGE ( fact_orders[delivery_days] ), fact_orders[is_delivered] = TRUE () )

Late Delivery Rate =
CALCULATE ( AVERAGE ( fact_orders[is_late] ), fact_orders[is_delivered] = TRUE () )

Revenue Previous Month =
CALCULATE ( [Revenue], DATEADD ( 'Date'[Date], -1, MONTH ) )

MoM Growth % =
DIVIDE ( [Revenue] - [Revenue Previous Month], [Revenue Previous Month] )

Revenue Last Year =
CALCULATE ( [Revenue], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

YoY Growth % =
DIVIDE ( [Revenue] - [Revenue Last Year], [Revenue Last Year] )

Repeat Customer Rate =
VAR CustomerOrders =
    ADDCOLUMNS (
        VALUES ( fact_orders[customer_unique_id] ),
        "@orders", CALCULATE ( [Delivered Orders] )
    )
VAR Buyers = COUNTROWS ( FILTER ( CustomerOrders, [@orders] >= 1 ) )
VAR Repeaters = COUNTROWS ( FILTER ( CustomerOrders, [@orders] >= 2 ) )
RETURN
    DIVIDE ( Repeaters, Buyers )

Bad Reviews From Late Orders % =
VAR BadReviews =
    CALCULATE ( [Delivered Orders], fact_orders[review_score] <= 2, NOT ISBLANK ( fact_orders[is_late] ) )
VAR BadAndLate =
    CALCULATE ( [Delivered Orders], fact_orders[review_score] <= 2, fact_orders[is_late] = 1 )
RETURN
    DIVIDE ( BadAndLate, BadReviews )

Category Revenue =
CALCULATE ( SUM ( fact_order_items[item_value] ), fact_order_items[is_delivered] = TRUE () )

Category Revenue Share % =
DIVIDE ( [Category Revenue], CALCULATE ( [Category Revenue], ALL ( fact_order_items[category] ) ) )

Segment Customers =
COUNTROWS ( customer_segments )

Segment Revenue =
SUM ( customer_segments[monetary] )
```

## Step 6. Check your numbers

With no filters applied, your measures should show these values (they match the Python notebooks and SQL results).
If one is different, check the column types from Step 1 first.

| Measure | Expected value |
|---|---|
| Revenue | R$ 15,419,774 |
| Delivered Orders | 96,478 |
| Customers | 93,358 |
| Avg Order Value | R$ 159.83 |
| Avg Review Score | 4.16 |
| Avg Delivery Days | 12.6 |
| Late Delivery Rate | 6.8% |
| Repeat Customer Rate | 3.0% |
| Bad Reviews From Late Orders % | 32.5% |

## Step 7. Build the pages

Use one colour theme across pages (the charts in this repo use blue `#2E5EAA`, red `#D1495B` for problems,
green `#2A9D8F` for good, grey `#9AA5B1` for context).

### Page 1: Executive Overview
- **Six KPI cards:** Revenue, Delivered Orders, Customers, Avg Order Value, Avg Review Score, Late Delivery Rate
- **Line chart:** Revenue by `Date[Month Start]`. Add a visual-level filter `fact_orders[in_trend_window] = True`
  so the half-empty months at the start and end are hidden
- **Bar chart:** Category Revenue by `fact_order_items[category]`, filter **Top N = 10** by Category Revenue
- **Bar chart:** Revenue by `fact_orders[customer_state]`
- **Slicers:** `Date[Year]`, `fact_orders[customer_state]`, `fact_order_items[category]`

### Page 2: Delivery & Customer Satisfaction
- **KPI cards:** Avg Delivery Days, Late Delivery Rate, Bad Reviews From Late Orders %
- **Column chart:** Avg Review Score by `delivery_status` (the key chart of the project)
- **Line chart:** Late Delivery Rate by `Date[Month Start]` (trend-window filter as above)
- **Table:** `customer_state`, Delivered Orders, Avg Delivery Days, Late Delivery Rate, Avg Review Score.
  Add **conditional formatting → background colour** on Late Delivery Rate and Avg Review Score
- **Scatter chart:** X = Avg Delivery Days, Y = Avg Review Score, Values = `customer_state`, Size = Delivered Orders

### Page 3: Customers & Payments
- **KPI cards:** Customers, Repeat Customer Rate
- **Clustered bar chart:** `customer_segments[segment]` with Segment Customers and Segment Revenue,
  both set to **Show value as → Percent of grand total**
- **Donut chart:** Delivered Orders by `payment_type`
- **Column chart:** Avg Order Value by `Installment Group`, filtered to `payment_type = credit_card`

### Finishing touches
- Add a title and a one-line insight text box to each page (for example: *"Late orders are 6.8% of deliveries but
  32.5% of 1-2 star reviews"*)
- Use **Edit interactions** so slicers filter all visuals but KPI cards don't cross-filter each other
- Add page navigation buttons (**Insert → Buttons → Navigator → Page navigator**)

## Step 8. Save and share

1. Save as `dashboard/olist_dashboard.pbix`
2. Take a screenshot of each page and save them as `images/dashboard_page1.png`, `images/dashboard_page2.png`,
   `images/dashboard_page3.png`
3. Export a PDF (**File → Export → Export to PDF**) as `dashboard/olist_dashboard.pdf` so recruiters without
   Power BI can still see it
4. Add the screenshots to the README under "Dashboard"
