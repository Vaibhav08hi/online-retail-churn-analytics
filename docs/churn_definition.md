# Churn Definition

## 1. Problem and approach

The retailer is a **non-contractual** business: customers never cancel anything, they just stop buying.
Churn therefore has to be defined as a long period of inactivity. This document explains how that
period was chosen from the data, how sensitive the results are to the choice, and how a leak-free
dataset was built for a prediction model.

## 2. Data and reference date

- **Data range:** 2009-12-01 to 2011-12-09 (cleaned sales from the `orders` and `order_items` tables)
- **Reference date:** 2011-12-10, the day after the last invoice. Recency is measured from this date, not from today's date, because the data is historical and every customer would otherwise look churned.
- **Purchases are counted from `orders` only.** Returns (cancelled invoices) are ignored, because a return is not a new purchase.
- **Customers:** 5,852 customers with at least one sale. Total spend: 17,068,567.97.

## 3. Why a 120-day threshold

To avoid guessing, I measured how long customers who came back actually waited between orders.
Same-day invoices were merged, so each gap is between two different order days.

| Measure | Value |
|---|---|
| Gaps analysed | 27,026 |
| Median gap | 32 days |
| 75th percentile | 70 days |
| 90th percentile | 148 days |
| 95th percentile | 221 days |

Share of normal gaps that are longer than each candidate threshold:

| Threshold | Normal gaps above it |
|---|---|
| 60 days | 29.16% |
| 90 days | 19.40% |
| 120 days | 13.47% |
| 180 days | 7.26% |

A 90-day rule would flag about 1 in 5 normal gaps as churn, which is too many false alarms for a
retailer with wholesale and seasonal buyers. **120 days** sits between the 75th and 90th percentiles of
normal behaviour and mislabels about 13% of normal gaps, close to the 10% I aimed for. A longer window
would be stricter but would leave less data to observe the outcome.

**Rule used:** a customer is churned if `days_since_last_purchase >= 120`.

## 4. Results

- **Overall churn rate:** 46.99 % (2750 of 5,852 customers)
- **One-time buyers:** 1,618 customers have a single invoice, and 1,673 have only one order day (so no gaps). That is about 29% of all customers.

Churn by number of orders:

| Orders | Customers | Churn rate |
|---|---|---|
| 1 order | 1618 | 74.91% |
| 2-3 orders | 1604 | 55.17% |
| 4+ orders | 2630 | 24.83% |

- **Overall churn rate:** 46.99% (2,750 of 5,852 customers)

Churn by spend quartile (1 = lowest spenders):

| Spend quartile | Customers | Churned | Churn rate | Spend range |
|---|---|---|---|---|
| 1 (lowest) | 1,463 | 1,089 | 74.44% | 2.95 to 339.50 |
| 2 | 1,463 | 836 | 57.14% | 339.60 to 856.01 |
| 3 | 1,463 | 597 | 40.81% | 856.03 to 2,240.90 |
| 4 (highest) | 1,463 | 228 | 15.58% | 2,241.42 to 580,987.04 |

Churn by country (top 5 by customers):

| Country | Customers | Churned | Churn rate |
|---|---|---|---|
| United Kingdom | 5,334 | 2,534 | 47.51% |
| Germany | 106 | 33 | 31.13% |
| France | 93 | 26 | 27.96% |
| Spain | 35 | 14 | 40.00% |
| Belgium | 28 | 11 | 39.29% |

Churn by year of first purchase:

| First purchase year | Customers | Churned | Churn rate |
|---|---|---|---|
| 2009 (December only) | 951 | 360 | 37.85% |
| 2010 | 3,364 | 1,960 | 58.26% |
| 2011 | 1,537 | 430 | 27.98% |

**What stands out:**
- Spend is the strongest separator: churn falls from 74.44% in the lowest spend quartile to 15.58% in the highest.
- Customers who first bought in 2010 churned most (58.26%). The 2011 figure is lower partly by construction, since anyone who first bought in the last 120 days cannot yet meet the churn rule. The 2009 group covers only December 2009, so it is not a full-year comparison.
- The UK makes up 91% of customers, so the overall rate mirrors the UK rate. Other countries show lower rates, but with 28 to 106 customers each the differences are not reliable.
- one-time buyers churn far more than repeat buyers, so getting a second purchase is the biggest retention lever. 

## 5. Sensitivity analysis

| Threshold (days) | Churned | Active | Churn rate |
|---|---|---|---|
| 60 | 3502 | 2350 | 59.84% |
| 90 | 2981 | 2871 | 50.94% |
| 120 | 2750 | 3102 | 46.99% |
| 180 | 2389 | 3463 | 40.82% |

The churn rate falls as the threshold rises, as expected. Moving from 60 to 180 days changes the rate by
19.02 percentage points.
The 120-day row matches the overall churn rate in section 4.

## 6. Time-based dataset for the prediction model

The snapshot churn flag cannot be used to train a model, because it labels customers from the same
"days since last purchase" value that would be used as a feature (data leakage). Instead:

- **Cutoff date:** 2011-08-12 (reference date minus 120 days)
- **Feature period:** orders before the cutoff only
- **Label period:** 2011-08-12 to 2011-12-09 (120 days). A customer is labelled churned (1) if they placed no order in it, otherwise 0.
- **Eligible customers:** those with at least one order before the cutoff: 5156 customers (696 new customers excluded)
- **Features:** recency, frequency, total spend, average order value, tenure, distinct products, orders in the last 90 days, return count and country
- **Result:** `churn_training_data` has 5156 rows with a label rate of 53.12%.

The label rate is lower than the snapshot churn rate because the label period covers the
Christmas buying season, when many customers return. **Leakage check:** the latest order date used
in any feature is 2011-08-11, before the cutoff.

## 7. Limitations

- December 2011 is a partial month, so the end of the data is slightly under-represented.
- About 23% of the raw rows had no Customer ID and are excluded, so all customer-level results cover identified customers only.
- Gaps exist only for customers who came back, so real waiting times are somewhat longer than the percentiles show.
- Seasonal and wholesale buyers can look churned between their buying peaks.
- Customers already inactive at the cutoff are almost always labelled 1, so recency will carry much of the model's prediction.
- Only one cutoff date is used, so the model is evaluated on a single period.

## 8. Files

- `sql/02_churn_definition.sql`: customer summary, gaps, churn flag, breakdowns, sensitivity
- `sql/03_training_data.sql`: the time-based `churn_training_data` view