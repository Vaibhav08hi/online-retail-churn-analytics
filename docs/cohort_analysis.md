# Cohort and Retention Analysis
 
## 1. Purpose
 
The churn rate compares customers of very different ages: a customer who first bought in late 2011 has
had far less time to churn than one who started in 2010. Cohort analysis fixes this by grouping customers
by the month of their first purchase and comparing groups at the same age. It answers three questions:
 
- **Retention:** what share of a cohort is still buying 1, 2, 3 and up to 12 months later?
- **Revenue:** how much does a cohort spend over time, and does the value come from the first month or from returning customers?
- **Repeat purchase rate:** what share of first-time buyers come back at all?
## 2. Definitions
 
- **Cohort month:** the calendar month of a customer's first order (for example 2010-03).
- **Months since start:** the number of calendar months between the cohort month and an active month. Month 0 is the first purchase month.
- **Active month:** a month in which the customer placed at least one order.
- **Repeat customer:** a customer who bought on **two or more different days**. Counting days instead of invoices avoids treating two invoices on the same day as a repeat (1,618 customers have one invoice, but 1,673 have a single order day).
- **90-day repeat rate:** the share of a cohort that bought again on a later day within 90 days of their first purchase date. It measures every cohort over the same window.
- Activity is counted from the `orders` table only. Returns are ignored, because a return is not a new purchase.
## 3. Data and caveats
 
- **Data range:** 2009-12-01 to 2011-12-09, 5,852 customers with at least one sale.
- **2009-12 is not a true acquisition cohort.** The data starts on 1 December 2009, so every existing customer who bought that month looks new. This cohort mixes real new customers with older ones and looks stronger than the rest.
- **2011-12 is excluded as an active month.** The data ends on 9 December, so only 9 days exist. Treating it as a full month would make every cohort's last cell look artificially low. This also removes the 2011-12 cohort from the retention and revenue views.
- **Months 0 to 12 only.** Few cohorts have data beyond 12 months.
- **Triangle shape.** Newer cohorts have fewer months of data, so the retention table is a triangle. Missing cells are months that have not happened yet, not zeros.
## 4. Method
 
All results come from SQL views in `sql/04_cohorts.sql`, built on `customer_summary`:
 
| View | What it contains |
|---|---|
| `customer_months` | One row per customer per active month, with cohort month and months since start |
| `cohort_retention` | Active customers and retention % for each cohort and month (long format) |
| `customer_month_revenue` | Revenue per customer per calendar month |
| `cohort_revenue` | Revenue, revenue per customer and cumulative revenue per customer by cohort and month |
| `customer_order_days` | Number of distinct order days per customer |
| `cohort_repeat_rate` | Repeat rate and 90-day repeat rate per cohort |
 
Checks run on the views: month 0 rows equal 5,852 (one per customer), months since start range from 0 to 24,
month 0 retention is 100% for every cohort, cumulative revenue never decreases within a cohort, and total
revenue through the joins equals the validated 17,068,567.97.
 
## 5. Results
 
### 5.1 Repeat purchase rate
 
Across all cohorts, **4,179 of 5,852 customers (71.41%) bought on two or more different days**, and 1,673 (28.59%)
bought on one day only.
 
Repeat rate by cohort (the 90-day column is only shown for cohorts with 90 full days of data, through 2011-08):
 
| Cohort | Cohort size | Repeat customers | One-time | Repeat rate | Repeat within 90 days |
|---|---:|---:|---:|---:|---:|
| 2010-08 | 163 | 112 | 51 | 68.71% | 49.69% |
| 2010-09 | 239 | 167 | 72 | 69.87% | 43.10% |
| 2010-10 | 375 | 245 | 130 | 65.33% | 38.40% |
| 2010-11 | 326 | 184 | 142 | 56.44% | 30.06% |
| 2010-12 | 76 | 42 | 34 | 55.26% | 15.79% |
| 2011-01 | 72 | 41 | 31 | 56.94% | 40.28% |
| 2011-02 | 125 | 74 | 51 | 59.20% | 32.00% |
| 2011-03 | 179 | 112 | 67 | 62.57% | 39.66% |
| 2011-04 | 106 | 64 | 42 | 60.38% | 37.74% |
| 2011-05 | 111 | 69 | 42 | 62.16% | 39.64% |
| 2011-06 | 108 | 65 | 43 | 60.19% | 47.22% |
| 2011-07 | 101 | 70 | 31 | 69.31% | 50.50% |
| 2011-08 | 107 | 61 | 46 | 57.01% | 48.60% |
| 2011-09 | 188 | 102 | 86 | 54.26% | n/a |
| 2011-10 | 221 | 90 | 131 | 40.72% | n/a |
| 2011-11 | 191 | 49 | 142 | 25.65% | n/a |
| 2011-12 | 28 | 0 | 28 | 0.00% | n/a |
 
The earlier cohorts (2009-12 to 2010-07) are in `data/cohort_repeat_rate.csv`.
 
### 5.2 Revenue: the January 2010 cohort (368 customers)
 
| Months since start | Revenue | Revenue per customer | Cumulative per customer |
|---:|---:|---:|---:|
| 0 | 157,879.40 | 429.02 | 429.02 |
| 1 | 38,643.35 | 105.01 | 534.03 |
| 2 | 49,117.83 | 133.47 | 667.50 |
| 3 | 56,247.02 | 152.85 | 820.35 |
| 4 | 57,474.07 | 156.18 | 976.53 |
| 5 | 59,977.37 | 162.98 | 1,139.51 |
| 6 | 51,652.25 | 140.36 | 1,279.87 |
| 7 | 46,946.42 | 127.57 | 1,407.44 |
| 8 | 58,387.96 | 158.66 | 1,566.10 |
| 9 | 73,380.97 | 199.40 | 1,765.51 |
| 10 | 75,142.27 | 204.19 | 1,969.70 |
| 11 | 39,179.04 | 106.46 | 2,076.16 |
| 12 | 42,020.85 | 114.19 | 2,190.35 |
 
### 5.3 Retention: the January 2010 cohort

| Months since start | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Retention % | 100.00 | [21.47] | [32.07] | [31.52] | [27.17] | [30.98] | [26.90] | [23.37] | [28.53] | [32.61] | [30.98] | [17.93] | [22.83] |
 
The full retention table for every cohort is in `data/cohort_retention.csv`.
 
## 6. Findings
 
1. **Most customers come back.** 71.41% of customers buy on at least two different days, and about 29% buy on one day only. Turning one-time buyers into repeat buyers is the main retention lever.
2. **Returning customers drive revenue.** For the January 2010 cohort, month 0 brings in 429.02 per customer, but the cumulative figure reaches 2,190.35 by month 12. About 80% of that first-year revenue (1,761 of 2,190) arrived after the first month.
3. **Revenue is seasonal.** Revenue per customer peaks in months 9 and 10 for this cohort (October and November 2010: 199.40 and 204.19), then falls in month 11 (December 2010: 106.46). This fits pre-Christmas ordering, probably from wholesale and gift buyers.
4. **Fast repeat is less common than eventual repeat.** The 90-day repeat rate mostly sits between 30% and 50% across cohorts, well below the 71.41% who eventually repeat. Many customers return, but not within the first three months.
5. **Newer cohorts look worse mainly because of time.** The plain repeat rate falls for the latest cohorts (54.26% for 2011-09, 40.72% for 2011-10, 25.65% for 2011-11) because they have had little time to buy again. The 90-day rate is the fair comparison.
6. **The 2010-12 cohort has the lowest 90-day rate (15.79%).** It has only 76 customers, and the 90 days after it include the quiet January period, so no cause should be read into it from this data.
## 7. Limitations
 
- **2009-12 is inflated** by customers who already existed before the data starts, so its retention and repeat rate look better than a true new-customer cohort.
- **2011-12 is excluded** because only 9 days of data exist for it.
- **Revenue per customer is an average.** A few very large wholesale accounts can pull it up, so the typical customer spends less. A median would be lower.
- **Small cohorts are noisy.** Cohorts of 100 customers or fewer can swing by several percentage points from chance alone.
- **About 23% of raw rows had no Customer ID** and are excluded, so results cover identified customers only.
- **Retention here means "active in that month".** A customer can skip a month and return, so a later month can be higher than an earlier one.
- **One retailer, two years.** Results may not generalise to other businesses.
## 8. Files
 
- `sql/04_cohorts.sql`: all cohort views and checks
- `data/cohort_retention.csv`: retention by cohort and month
- `data/cohort_revenue.csv`: revenue by cohort and month
- `data/cohort_repeat_rate.csv`: repeat rate by cohort
 