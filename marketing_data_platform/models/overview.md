{% docs __overview__ %}

# Marketing Data Platform

Unifies Facebook Ads and Snapchat Ads performance into one governed, tested dataset.

## Layers

| Layer | Purpose |
|---|---|
| Sources | Raw files as delivered, in Databricks Unity Catalog. Never modified. |
| Staging | One model per raw table. Renaming, type casting and source-level cleanup only. |
| Intermediate | Joins each platform's hierarchy and unions both platforms into one shape. |
| Marts | A fact table of keys and metrics, dimensions for names, and a view for consumption. |

## Where to start

Query `mart_marketing_performance`. It has one row per platform per ad per day, with
campaign and ad names already attached.

## Rules every consumer should know

- Spend is in `currency_code`. Group by currency before adding spend across rows.
- Missing clicks and impressions are null, which means unknown and not zero.
- CTR, CPC and CPM are per row. For totals, recompute them from summed spend, clicks and impressions.
- Facebook data covers 2025 and Snapchat data covers 2024.

{% enddocs %}