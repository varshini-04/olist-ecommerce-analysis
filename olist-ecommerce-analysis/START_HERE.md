# START HERE: How to make this project yours

This file is for you, not for GitHub. Don't upload it. The project itself is in the
`olist-ecommerce-analysis/` folder.

---

## Your 7-day plan

| Day | Task | Done when... |
|---|---|---|
| 1 | Install Python + Jupyter (Anaconda is easiest). Download the data from Kaggle into `data/raw/` | `pip install -r requirements.txt` works and the 9 CSVs are in place |
| 2 | Run `01_data_cleaning.ipynb` **cell by cell**. Read every comment | You can explain every one of the 13 data-quality issues without notes |
| 3 | Run `02_exploratory_analysis.ipynb` cell by cell | You can explain how each chart was made and what it shows |
| 4 | Run `03_customer_analytics_rfm_cohort.ipynb`. Look up RFM and cohort analysis on YouTube if they are new to you | You can draw the RFM logic on paper |
| 5 | Run `python sql/run_queries.py`. Then type out 5 of the queries yourself from memory | You can write a LAG and a ROW_NUMBER query without looking |
| 6-7 | Build the Power BI dashboard using `dashboard/POWER_BI_GUIDE.md`. Save screenshots | Your numbers match the "Check your numbers" table |
| 7 | Add one analysis of your own (ideas below), upload to GitHub, update resume and LinkedIn | Repo is public and linked on your resume |

**Why this matters:** interviewers pick one chart or query and ask "how did you do this?" or "why did you choose
that?". If you have run and changed the code yourself, you can answer confidently.

---

## Make it yours: add one extra analysis

Pick one and add it as a new section in notebook 02 or a new query in the SQL file:

- **Freight analysis:** which categories have the highest freight as a % of price? Does high freight lower reviews?
- **Seller performance:** which sellers have the most late deliveries or worst reviews (minimum 50 orders)?
- **Review text:** what words appear most in 1-star review comments? (`review_comment_message` column)
- **Distance:** use the geolocation table to calculate the seller-to-customer distance and compare it with delivery days.
- **Weekend vs weekday:** do weekend orders take longer to deliver?

This also gives you a great interview answer: *"I extended the analysis by looking at..."*

---

## Upload to GitHub

**Easy way (GitHub Desktop):**
1. Create a free account at github.com and install GitHub Desktop.
2. **File → Add local repository →** choose the `olist-ecommerce-analysis` folder → **Create repository**.
3. Commit, then click **Publish repository**. Untick "Keep this code private".

**Command line:**
```bash
cd olist-ecommerce-analysis
git init
git add .
git commit -m "E-commerce sales and customer behavior analysis"
git branch -M main
git remote add origin https://github.com/<your-username>/olist-ecommerce-analysis.git
git push -u origin main
```

The `.gitignore` already keeps the large CSV files out of GitHub.

**Before publishing:**
- Replace `[Your Name]`, the LinkedIn link, and the email at the bottom of `README.md`.
- Add your Power BI screenshots to `images/` and a "Dashboard" section to the README.
- Pin the repository on your GitHub profile.

---

## Resume entry

**E-Commerce Sales & Customer Behavior Analysis** | Python, SQL, Power BI | github.com/<you>/olist-ecommerce-analysis
- Cleaned and analyzed 100K+ orders across 8 relational tables, documenting 13 data-quality issues, including a customer-ID flaw that would have hidden all repeat buyers.
- Wrote 15 SQL queries (CTEs, window functions) and found that late deliveries were only 6.8% of orders but caused 32.5% of all 1-2 star reviews.
- Built RFM segmentation and cohort analysis showing only 3% of customers return, and identified two segments holding 56% of revenue for retention and win-back campaigns.
- Designed a 3-page Power BI dashboard tracking revenue, delivery performance, and customer segments.

Only list Power BI after you have built the dashboard.

---

## Your 2-minute project story (practise saying this out loud)

> "I analyzed about 100,000 real orders from Olist, a Brazilian e-commerce marketplace. Revenue had grown 143% year
> over year but flattened in 2018, so I wanted to understand what was driving that and what was hurting customers.
>
> I started by cleaning eight related tables. The most important catch was that the customer ID changes with every
> order, so I had to use a different column to identify real customers. Otherwise the repeat rate would have shown as zero.
>
> I used SQL and Python to analyze the data and found three main things. First, late deliveries are only 6.8% of
> orders but cause about a third of all bad reviews. Second, customers in Rio and the Northeast are late two to three
> times more often than in São Paulo. Third, only 3% of customers ever come back, which explains why growth
> stalled: the business depends entirely on new customers.
>
> I segmented customers with RFM analysis and found two groups holding 56% of revenue, then recommended specific
> actions for each: realistic delivery estimates by region, a second-purchase campaign, and a win-back campaign.
> Finally I built a Power BI dashboard so the team could track these metrics."

---

## Interview questions you are likely to get (with answers from this project)

**1. Why did you use `customer_unique_id` instead of `customer_id`?**
Olist creates a new `customer_id` for every order. There are 99,441 customer IDs but only 96,096 real people. If I had
used `customer_id`, every customer would appear to buy exactly once and the repeat rate would be 0%.

**2. How did you define revenue? Why not use the payments table?**
Revenue = item price + freight on delivered orders. Payments include installment interest and vouchers, and 249
orders differed from the item total by more than R$1. Using items also let me split revenue by product category.

**3. How did you define a "late" delivery?**
Delivered on a later calendar day than the estimated delivery date shown to the customer. I compared dates, not
timestamps, because the estimate has no time of day.

**4. Why did you exclude some months from the trend analysis?**
2016 had only 329 orders (the platform was launching) and Sep-Oct 2018 had 20 (the data export stopped). Including
them would show fake growth at the start and a fake crash at the end. I used January 2017 to August 2018.

**5. Late deliveries correlate with bad reviews, but does that prove they cause them?**
Not on its own. It could partly be other factors like distance or product type. But the pattern is consistent:
review scores drop steadily as the delay grows (4.29 → 3.29 → 2.10 → 1.67), and states that are slow but on time
(Amazonas, Amapá) still get high reviews. To prove it, I would recommend an A/B test on delivery estimates.

**6. What would the business gain if it fixed late deliveries?**
If late orders were reviewed like on-time orders, the average review would rise from 4.16 to about 4.29. About 4,000
of the roughly 12,300 one- and two-star reviews came from late orders. This is an estimate that assumes lateness is
the cause.

**7. Why didn't you use normal quintiles for Frequency in RFM?**
97% of customers have exactly one order, so quintiles would put almost everyone in the same group. I split customers
into one-time and repeat buyers instead, and used quintiles only for Recency and Monetary.

**8. How did you check that your results were correct?**
Three ways. I added assert checks after cleaning (one row per order, no rows lost in joins, totals match). I wrote the
same analysis in SQL and in Python and confirmed every number matched. I also checked the raw files against the
official dataset.

**9. Explain a window function you used.**
- `LAG` in Q2 compares each month's revenue to the previous month for month-over-month growth.
- `ROW_NUMBER` with `PARTITION BY order_id` keeps only the latest review per order.
- `NTILE(10)` splits sellers into deciles, which showed that the top 10% generate 66% of revenue.

**10. What was the hardest part?**
Finding data problems that don't cause errors but give wrong answers. Examples: the customer ID issue, zip codes
losing leading zeros if read as numbers, and 30% of "repeat" customers being people who split one shopping trip into
two orders on the same day.

**11. What would you do next?**
Build a model to predict which customers are likely to return. Analyze review text to see what customers complain
about. Use the geolocation data to measure seller-to-customer distance.

**12. What is the difference between WHERE and HAVING?** (Q6 uses both ideas)
WHERE filters rows before grouping. HAVING filters groups after aggregation. For example, `HAVING COUNT(*) >= 500`
keeps only categories with at least 500 orders.

---

## Key numbers to remember

| Metric | Value |
|---|---|
| Delivered orders / customers | 96,478 / 93,358 |
| Revenue | R$ 15.42M |
| Average order value | R$ 159.83 |
| YoY growth (Jan-Aug) | +143% |
| Late deliveries | 6.8% of orders, 32.5% of 1-2 star reviews |
| Review: on time vs 4+ days late | 4.29 vs ~2 |
| Repeat customers | 3.0% |
| Top 10% sellers' share of revenue | 66% |
| SP vs Northeast delivery time | 8.8 vs 20 days |
