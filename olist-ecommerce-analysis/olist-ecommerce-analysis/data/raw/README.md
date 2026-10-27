# Raw data

The raw CSV files are not stored in this repository (about 120 MB). To get them:

1. Go to https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce (free Kaggle account needed)
2. Click **Download** and unzip the archive
3. Put these 9 files directly in this `data/raw/` folder:

| File | Rows |
|---|---|
| olist_customers_dataset.csv | 99,441 |
| olist_geolocation_dataset.csv | 1,000,163 (not used) |
| olist_order_items_dataset.csv | 112,650 |
| olist_order_payments_dataset.csv | 103,886 |
| olist_order_reviews_dataset.csv | 99,224 |
| olist_orders_dataset.csv | 99,441 |
| olist_products_dataset.csv | 32,951 |
| olist_sellers_dataset.csv | 3,095 |
| product_category_name_translation.csv | 71 |

Then run `notebooks/01_data_cleaning.ipynb`, which creates the clean tables in `data/processed/`.
