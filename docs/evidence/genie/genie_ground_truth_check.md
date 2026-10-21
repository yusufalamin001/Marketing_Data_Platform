# Genie ground truth check

Date: 2026-10-21
Data product tested: `mart_marketing_performance` (dev schema), through a Databricks Genie space.

## Method

Each answer from Genie was checked against figures recomputed independently from the
raw CSV files, outside dbt and Databricks:

- Facebook stats joined to accounts (for currency) and to campaigns (for names)
- Snapchat stats joined through ads and ad groups to campaigns, using the latest
  version of each ad group
- Missing clicks (stored in the raw files as the text `null`) were treated as missing
  and ignored in sums, the same rule the dbt models apply

Because the check does not use any dbt output, a match confirms the whole chain:
raw files, staging, intermediate, fact, consumption view and agent.

## Results

| # | Question | Genie answer | Recomputed from raw files | Verdict |
|---|---|---|---|---|
| 1 | How much did we spend on Facebook in December 2025? | 768,265 USD | USD 768,265.10. No EUR spend in December, because the EUR accounts stop on 2025-09-17 | Match |
| 2 | Which campaign had the highest number of clicks? | `usa_ios_display_ggl_awareness_20230916_interest-stack-v3_video-views`, 1,389,414 clicks | Same campaign, 1,389,414 clicks. Second place is 421,547. Best Snapchat campaign is 4,965 | Match |
| 3a | Facebook spend, USD | 6.87M across 365 days (2025-01-01 to 2025-12-31) | 6,869,536.99 across 365 days | Match |
| 3b | Facebook spend, EUR | 2.56M across 260 days (2025-01-01 to 2025-09-17) | 2,562,561.24 across 260 days | Match |
| 3c | Snapchat spend, EUR | 30,530 across 133 days (2024-01-01 to 2024-12-02) | 30,529.54 across 133 days | Match |
| 3d | Facebook EUR versus Snapchat EUR (retest) | About 84 times higher | 2,562,561.24 / 30,529.54 = 83.9 | Match |

## Behaviour against the documented rules

| Rule in the instructions | Observed |
|---|---|
| Never add EUR and USD together | Followed in both attempts. Spend was reported per currency |
| Flag that Facebook (2025) and Snapchat (2024) do not overlap | Followed in both attempts |
| Do not state which platform spent more unless currency and period both match | Not fully followed. See below |

## Attempts

| Attempt | What happened | Issue found | Action |
|---|---|---|---|
| 1 | All figures correct, currencies separated | Stated that Facebook "significantly outspent" Snapchat, comparing USD with EUR and 2025 with 2024 | Added an instruction on like-for-like comparison |
| 2 | All figures correct. Added a caveat about differing periods and currencies, and an EUR-to-EUR comparison | Headline still says "significantly outspent". Also infers that Snapchat activity "appears limited" from the number of days with data, which the table does not support | Documented as a known limitation |

## Known limitations

- The comparison wording is weaker than the numbers. The conclusion is safe only because the
  gap is large, about 84 times in EUR.
- Genie is not deterministic, so one correct run is evidence and not a guarantee.
- Only three questions were tested.

## Next step

Save the three questions with their correct SQL as Genie benchmarks, so the check can be
rerun after any change to the model or the instructions.