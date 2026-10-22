# Marketing Data Platform

Facebook Ads and Snapchat Ads performance in one governed, tested and documented dataset, built with Databricks, dbt and Elementary.

Before this project, marketers opened each advertising platform, exported to Excel and merged the numbers by hand. Now there is one model, `mart_marketing_performance`, with one row per platform per ad per day. Analysts query it with SQL, BI tools can connect to it, and an AI agent can answer questions from it.

## At a glance

| | |
|---|---|
| Sources | 9 raw tables: 5 Facebook, 4 Snapchat |
| Raw volume | Facebook stats 92,300 rows (2025), Snapchat stats 2,809 rows (2024) |
| dbt project | 16 models, 116 data tests, 9 sources, 2 exposures |
| Final model | `mart_marketing_performance`, a view over `fct_marketing_spend`, `dim_campaign` and `dim_ad` |
| Fact table size | 93,352 rows |
| Warehouse | Databricks with Unity Catalog |
| Observability | Elementary 0.22.0 |
| Environments | dev, ci, staging, production |
| Production authentication | Databricks service principal over OAuth, no personal access token |
| CI/CD | GitHub Actions |

## Architecture

```
Raw CSV files
     |
     v
bronze_production              staging          intermediate          marts                  consumers
  facebook_ads   (5 tables)    9 views          2 ephemeral models    fct_marketing_spend    Analysts (SQL, Databricks)
  snapchat_ads   (4 tables)    one per raw      1 unified view        dim_campaign           BI tools
  raw, never edited            table                                  dim_ad                 AI agent (Genie)
                                                                      mart_marketing_performance
```

| Layer | What it does | Materialization |
|---|---|---|
| Raw (bronze) | The files exactly as delivered. dbt only reads from here | Tables loaded once |
| Staging | One model per raw table. Rename, cast types, fix source quirks. No joins, no business rules | View |
| Intermediate | Join each platform's hierarchy, roll Snapchat up to the Facebook grain, union both platforms | Ephemeral for the per-platform models, view for the union |
| Marts | A fact of keys and metrics, dimensions for names, and a consumption view that joins them | Incremental, table, view |

Data is separated by catalog:

| Catalog | Holds |
|---|---|
| `bronze_production` | Raw data, shared by every environment |
| `development` | A developer's own dbt output |
| `ci_development` | One throwaway schema per pull request |
| `silver_staging`, `silver_production` | Staging and intermediate models, and Elementary's tables |
| `gold_staging`, `gold_production` | The fact, dimensions and consumption view |

## Data model

| Model | Grain | Key |
|---|---|---|
| `stg_facebook_ads_stats` | one ad per day | `ad_id` + `report_date` |
| `stg_snapchat_ads_stats` | one ad per day per country | `ad_id` + `report_date` + `country_code` |
| `int_marketing_ads` | one ad per day per platform | `platform` + `ad_id` + `report_date` |
| `fct_marketing_spend` | one ad per day per platform | `marketing_spend_key`, a hash of platform, ad id and date |
| `dim_campaign` | one campaign per platform | `campaign_key`, a hash of platform and campaign id |
| `dim_ad` | one ad per platform | `ad_key`, a hash of platform and ad id |
| `mart_marketing_performance` | one ad per day per platform | `marketing_spend_key` |

`mart_marketing_performance` columns: `platform`, `report_date`, `account_id`, `currency_code`, `campaign_id`, `campaign_name`, `ad_group_id`, `ad_group_name`, `ad_id`, `ad_name`, `ad_status`, `spend`, `impressions`, `clicks`, `ctr`, `cpc`, `cpm`.

### Rules every consumer needs to know

- **Spend is in `currency_code`.** Facebook has USD and EUR accounts and Snapchat is EUR. Group by currency before adding spend. Never add USD and EUR.
- **Missing clicks and impressions are null, and null means unknown, not zero.**
- **`ctr`, `cpc` and `cpm` are per row.** They are null when the denominator is zero or missing. For totals, recompute them from summed values: `sum(clicks) / sum(impressions)`, `sum(spend) / sum(clicks)`, `sum(spend) / sum(impressions) * 1000`. Averaging the stored ratios gives wrong answers.
- **Facebook covers 2025 and Snapchat covers 2024.** The two platforms do not overlap in time.

## What I found in the raw data

I profiled all nine files before writing any model. These findings shaped the design.

| Finding | How it was handled |
|---|---|
| Facebook stats are one row per ad per day. Snapchat stats are one row per ad per day per country | The unified grain is ad per day per platform. Snapchat is summed across countries in the intermediate layer. Staging keeps country, and the uniqueness test uses three columns |
| Facebook has no currency column in its stats. Currency comes from the account. Snapchat carries it in the stats. Facebook has USD and EUR accounts | `currency_code` is kept on every row and never summed across. There is no exchange rate table, so I did not convert |
| Missing impressions and clicks arrive as the text `null`, not a real null. The first staging test run failed on this | Staging converts it with `nullif(trim(col), 'null')` before casting. `try_cast` was avoided because it would also hide genuinely corrupt values |
| Facebook IDs are 17 to 18 digit integers. Snapchat IDs are UUID strings | All IDs are cast to string in staging. Keys hash the platform with the ID, so the two cannot collide |
| Snapchat ad groups come from a history table. Three ad groups appear twice | Staging keeps the latest version per ad group. Joining the raw table would have doubled their spend |
| 304 of 2,513 Snapchat ads point to ad groups missing from the ad group file | None of those ads have performance data, so no spend is affected. The test is set to warn so the gap stays visible |
| One Snapchat row has country `US`, in a dataset that is otherwise DE, CH and AT | Kept. The test is set to warn |
| Facebook EUR accounts have data only to 2025-09-17, and Snapchat ends 2024-12-02 | Documented. Not a modelling problem |

## Decisions and reasoning

### Why a fact, two dimensions and a consumption view

My first version put campaign, ad group and ad names on every fact row. That breaks with an incremental model that only refreshes recent days. If a campaign is renamed, old rows keep the old name and new rows get the new one, so one campaign appears under two names and spend by campaign silently splits.

Now names live once, in `dim_campaign` and `dim_ad`, which are rebuilt in full on every run. The fact holds only keys and metrics. `mart_marketing_performance` joins them back together as a view, so analysts, BI tools and an AI agent query one flat model with no joins to get wrong, and it can never serve a stale name.

The dimensions are built from staging, not from the union. Building them from the union would list only ads that have performance data, and would pick arbitrary names when a name changed. A missing parent stays a real null. `generate_surrogate_key` would turn a null campaign into a valid-looking hash, so `dim_ad` returns null for the Snapchat ads whose ad group is missing.

### Materializations

| Model | Materialization | Why |
|---|---|---|
| Staging | view | Cheap, always reads current raw data, stores no second copy |
| Per-platform intermediate models | ephemeral | Each feeds exactly one model. Storing them would add two objects nobody queries. They are inlined as CTEs. The trade-off is that they cannot be queried directly while debugging |
| `int_marketing_ads` | view | Queried and tested directly. At this data size there is no performance reason to store it |
| `fct_marketing_spend` | incremental, merge | New data arrives daily, and platforms restate recent numbers |
| Dimensions | table | Small, and a full rebuild guarantees current names |
| `mart_marketing_performance` | view | Stores nothing and joins on read |

Materializations are set per folder in `dbt_project.yml`, so every choice is visible in one file. The incremental strategy and unique key stay in the fact model because they belong to that model.

### Incremental processing

- **Strategy: merge on `marketing_spend_key`.** An insert-only model keeps a stale row and adds the corrected one as a duplicate. A merge updates rows that exist and inserts rows that do not.
- **Lookback window of 3 days (`lookback_days`).** Ad platforms restate recent numbers as conversions and billing settle, so each run reloads the last days and not only the newest one. Longer is safer, shorter is cheaper. Three days is an assumption and is a project variable so it can be tuned. It reloads four calendar days, because the window runs from three days before the latest date through the latest date.
- **A watermark per platform, not one global date.** Facebook ends in 2025 and Snapchat in 2024. A single maximum date would be in 2025 and would skip a late Snapchat load. A platform with no rows yet loads everything.
- **Evidence.** `DESCRIBE HISTORY` on the fact shows run 1 as a create of 93,352 rows and run 2 as a `MERGE` that updated 1,509 rows and inserted none. The rows rewritten were Facebook 2025-12-28 to 2025-12-31 (1,481 rows) and Snapchat 2024-11-29 to 2024-12-02 (28 rows). Each platform's window sits at the end of its own data.
- `--full-refresh` rebuilds the table if logic changes.

### Tests

The tests protect the model from bad data, and each has a reason.

| Test | Why it exists |
|---|---|
| Unique and not null on every primary key | A duplicate key means double-counted spend |
| Grain tests (`unique_combination_of_columns`) on both stats models and the union | Confirms the grain statements are true in the data |
| `relationships` from the fact to both dimensions, and from Snapchat stats to ads | A fact row with no dimension row would drop out of reports |
| `accepted_values` on platform, currency and ad status | Alerts when a platform sends a value I have not seen |
| `accepted_range` of at least 0 on spend, impressions, clicks, CPC and CPM | Negative metrics are impossible and mean bad data |
| CTR between 0 and 1, severity warn | Signals bad data without blocking a build |
| **Spend reconciliation (3 singular tests)** | Total spend per platform in the union, the fact and the consumption view must equal the layer before it. This catches the worst bug in a pipeline, silently gaining or losing money through a join or an incremental merge |

Severity is a deliberate choice. Errors are for things that would corrupt numbers. Warnings are for findings worth seeing that do not threaten correctness, such as the 304 orphan ad group links and the stray US row.

### Environments

The code never changes between environments. Only the dbt target does, selected with `DBT_TARGET`.

| Target | Acts as | Staging and intermediate | Marts | Elementary |
|---|---|---|---|---|
| `dev` | the developer, personal access token | `development.<dev schema>` | same | `<dev schema>_elementary` |
| `ci` | service principal | `ci_development.pr_<number>` | same | same |
| `staging` | service principal | `silver_staging.analytics` | `gold_staging.analytics` | `silver_staging.elementary` |
| `production` | service principal | `silver_production.analytics` | `gold_production.analytics` | `silver_production.elementary` |

Two macros, `generate_database_name` and `generate_schema_name`, decide where each model lands. In staging and production they send working models to silver and the data product to gold, with exact schema names. In dev and CI they keep one catalog and one schema, because a sandbox does not need the extra structure.

Raw data is shared by every environment. It is immutable and small, and copies would drift apart. The protection is that every environment has read-only access to it.

### Production security

CI, staging and production authenticate as a Databricks service principal over OAuth. No person's credentials are in anything automated, and no personal access token is used outside local development.

Permissions follow least privilege and are versioned in `infra/unity_catalog_grants.sql`:

- **Raw data is read only**, granted on the two schemas this project uses, not on the whole bronze catalog.
- **Environment catalogs allow `CREATE SCHEMA` only.** dbt creates the schemas it needs, and a schema's creator owns it, so the principal has full rights on what it builds and nothing else.
- **No `CREATE CATALOG` and no write access to bronze.** A leaked secret cannot damage raw data or create catalogs. This deliberately differs from the example in the case study brief.
- The principal also needs **Can use** on the SQL warehouse, which is set in Databricks.
- The OAuth secret uses the all-APIs scope because that is what dbt requests. The scope limits which APIs a token may call, and Unity Catalog grants limit what data it can touch, so the grants file is the real security boundary.

I checked the ownership claim directly. A CI-target run created a schema, and `DESCRIBE SCHEMA EXTENDED` showed the service principal's application ID as owner, not a person.

### CI/CD

```
feature branch -> pull request -> CI (target: ci) -> merge to main -> staging -> production
```

- **CI** runs on every pull request. It builds the whole project into `ci_development.pr_<number>`, then drops that schema, even when the build fails. The drop macro refuses to run unless the target is `ci` and the schema name starts with `pr_`.
- **CI runs the full project, not only changed models.** The data is small and a full build takes about two minutes. Selecting only changed models needs a saved production manifest, and a partial selection can select a cross-model test while skipping the models it needs, so the test never runs. A CI that silently skips tests is worse than a slow one.
- **Elementary is excluded in CI** (`--exclude "package:elementary" "test_name:schema_changes"`). A fresh per-pull-request schema has no run history, so schema change tests could only record a baseline. Elementary runs in staging and production, where history builds up.
- **No path filter on CI**, so every pull request reports the `dbt-ci` check. A required check that is skipped for some pull requests would block them from merging.
- **Deployment** starts on a merge to `main`. It builds and tests in staging, then production runs only if staging passed. The production job uses a GitHub environment named `production`. Deployments queue and never cancel each other, because cancelling a half-finished production build is worse than waiting.
- **Fast failure.** `DBT_CONNECT_RETRIES` is 5 in CI, so a broken secret fails in about a minute. A broken secret once retried for many minutes before I made this configurable.
- **Locked installs.** `uv sync --frozen` installs exactly what `uv.lock` records.
- The production job generates the static dbt documentation and keeps it as a workflow artifact.

Result of the CI run on pull request 10: 126 passed, 2 warnings, 0 errors, about two minutes. It dropped `ci_development.pr_10` and `ci_development.pr_10_elementary` afterwards. In production, Elementary recorded 114 passes and 2 warnings, which is the 116 tests including the 4 schema change tests that CI skips.

## Setup

### Requirements

- A Databricks workspace with Unity Catalog and a SQL warehouse
- Python 3.12 and [uv](https://docs.astral.sh/uv/)
- Git

### 1. Load the raw data

Load the nine CSV files as delivered into `bronze_production`, one table per file, and do not clean anything:

| Schema | Tables |
|---|---|
| `facebook_ads` | `accounts`, `adgroups`, `ads`, `ads_stats`, `campaigns` |
| `snapchat_ads` | `adgroups`, `ads`, `ads_stats`, `campaigns` |

Check that the Facebook IDs kept all their digits, and that row counts match the files (92,300 for Facebook stats, 2,809 for Snapchat stats).

### 2. Create the catalogs

```sql
CREATE CATALOG IF NOT EXISTS development;
CREATE CATALOG IF NOT EXISTS ci_development;
CREATE CATALOG IF NOT EXISTS silver_staging;
CREATE CATALOG IF NOT EXISTS gold_staging;
CREATE CATALOG IF NOT EXISTS silver_production;
CREATE CATALOG IF NOT EXISTS gold_production;
```

Do not create the schemas inside them. dbt creates them, and the service principal must be their creator so it owns them.

### 3. Create the service principal

1. Create a service principal in Databricks and copy its application ID.
2. Generate an OAuth secret with the all-APIs scope. It is shown once.
3. Give it **Can use** on the SQL warehouse.
4. Replace the placeholders in `infra/unity_catalog_grants.sql` and run it.

### 4. Configure the project

```
git clone https://github.com/yusufalamin001/Marketing_Data_Platform.git
cd Marketing_Data_Platform
uv sync
cp .env.template .env
```

Fill in `.env`:

| Variable | Purpose |
|---|---|
| `DATABRICKS_PAT_TOKEN` | Personal access token, for the `dev` target only |
| `DEV_CATALOG` | Catalog for local builds, for example `development` |
| `DEV_SCHEMA` | Your own schema, for example `dbt_yourname` |
| `DBT_TARGET` | Optional. Defaults to `dev` |
| `DBX_ID_APPLICATION_ID` | Service principal application ID, for `ci`, `staging` and `production` |
| `DBX_SECRET` | Service principal OAuth secret, for the same targets |

`.env` is in `.gitignore`. The workspace host and warehouse path are in `profiles.yml`. They identify the workspace but cannot authenticate anyone. In GitHub, the two service principal variables are repository secrets.

### 5. Build

Run dbt from the project folder:

```
cd marketing_data_platform
uv run --env-file ../.env dbt deps
uv run --env-file ../.env dbt debug
uv run --env-file ../.env dbt build
```

## Everyday commands

```
# one model and everything upstream
uv run --env-file ../.env dbt build --select +fct_marketing_spend

# generate the static documentation
uv run --env-file ../.env dbt docs generate --static

# generate the Elementary report
uv run --env-file ../.env edr report --profiles-dir . --profile-target dev

# see where every model would be built, without running anything
uv run --env-file ../.env dbt ls --resource-type model --output json --output-keys "name database schema"
```

## Using the data

Total spend by platform and currency, with ratios recomputed from sums:

```sql
select
    platform,
    currency_code,
    sum(spend)                                      as total_spend,
    sum(impressions)                                as total_impressions,
    sum(clicks)                                     as total_clicks,
    sum(clicks) / nullif(sum(impressions), 0)       as ctr,
    sum(spend)  / nullif(sum(clicks), 0)            as cpc,
    sum(spend)  / nullif(sum(impressions), 0) * 1000 as cpm
from gold_production.analytics.mart_marketing_performance
group by platform, currency_code
order by platform, currency_code;
```

Campaigns with the most clicks:

```sql
select platform, campaign_name, sum(clicks) as total_clicks
from gold_production.analytics.mart_marketing_performance
group by platform, campaign_name
order by total_clicks desc
limit 10;
```

Monthly spend by platform:

```sql
select
    platform,
    currency_code,
    date_trunc('month', report_date) as month,
    sum(spend)                       as total_spend
from gold_production.analytics.mart_marketing_performance
group by platform, currency_code, date_trunc('month', report_date)
order by month, platform;
```

## Observability

[Elementary](https://www.elementary-data.com/) records every dbt test result and run in tables, and its report shows them over time. The package writes to its own schema so monitoring data never mixes with models. Its end-of-run hook uploads results after every dbt command.

- **Schema change tests** run on `stg_facebook_ads_stats`, `stg_snapchat_ads_stats`, `fct_marketing_spend` and `mart_marketing_performance`. These are the interfaces where a silent column change would do the most damage.
- **No anomaly tests, on purpose.** Anomaly detection compares recent data with a training window. The data here is a fixed historical extract, so there are no recent buckets and such a test would give no meaningful signal. This would change with live data.
- **Version 0.22.0 for both the package and the CLI**, because the two must share a minor version. It matches the course version and builds cleanly on dbt 1.12.
- **Cost:** a full build went from about 1 minute 10 seconds to about 4 minutes 40 seconds with Elementary. The end hook alone takes about 70 seconds. This is why CI skips it.
- The full report is in `docs/elementary_report.html`. A temporary column added to a staging model was flagged by `elementary.schema_changes`, and the change was never committed. Screenshots are in `docs/evidence/elementary/`.

## Documentation and lineage

dbt documentation describes every source, model, important column and metric, and includes the grain of each model. Generated static HTML is in `docs/index.html`, and the lineage graph is in `docs/evidence/lineage/lineage_graph_full.png`. Descriptions are also stored as comments on the tables in Unity Catalog (`persist_docs`), so consumers can read them where they query.

## AI agent consumption

To test whether an agent can answer from the model's names and documentation alone, `mart_marketing_performance` was put behind a Databricks Genie space with instructions for the rules above.

Three questions were asked, and every figure was checked against values recomputed from the raw CSV files, outside dbt and Databricks:

| Question | Result |
|---|---|
| Facebook spend in December 2025 | Matched: 768,265 USD |
| Campaign with the most clicks | Matched: 1,389,414 clicks |
| Facebook versus Snapchat spend | Matched. Spend was split by currency and the different years were flagged |

The first run compared USD with EUR and 2025 with 2024, and called Facebook the higher spender. I added an instruction on like-for-like comparisons. The retest added a caveat, but the headline still said "significantly outspent". This is recorded as a known limitation. Method, results and attempts are in `docs/evidence/genie/genie_ground_truth_check.md`.

## Evidence

Test records are in `docs/evidence/`. See `docs/evidence/README.md` for the index.

| Folder | Shows |
|---|---|
| `lineage/` | The lineage graph from the generated documentation |
| `genie/` | The AI agent test and its ground truth check |
| `elementary/` | Schema change detection in Elementary |
| `service_principal/` | The pipeline owning the schemas it builds |
| `ci/` | Branch protection, the required check, the CI run and the deployment |

## Known limitations

- **No overlap between platforms.** Facebook is 2025 and Snapchat is 2024, so platform trends over time cannot be compared.
- **No currency conversion.** There is no exchange rate table, so spend must be grouped by currency.
- **Totals can understate clicks.** Sums ignore nulls, so a day with a missing click count contributes nothing to click totals, and its ratios are null.
- **Ratios are stored per row for convenience.** They must be recomputed from sums when aggregated.
- **Source freshness is set to 2 days, as in the course.** The data is static, so the check measures when the tables were loaded and warns after two days. That warning is expected and is not a pipeline failure.
- **The lookback window of 3 days is an assumption** about how late platforms revise numbers.
- **One service principal serves all environments,** with repository secrets.
- **`docs/index.html` is a snapshot.** It must be regenerated when models or descriptions change.
- **The Genie answer wording** for cross-platform comparisons is looser than the numbers behind it.

## Future work

- A BI dashboard on `mart_marketing_performance`. It is declared as a planned exposure and is not built.
- Publish the dbt documentation on GitHub Pages from the production workflow.
- A separate service principal per environment, stored as environment secrets.
- Pin GitHub Actions to commit hashes, and move off the Node 20 versions.
- An exchange rate table, so spend can be reported in one currency.
- Anomaly tests, once the pipeline receives live data.
- A small macro for the repeated `nullif(trim(col), 'null')` cast.
- Save the Genie questions as benchmarks so the check can be rerun after any change.

## Repository layout

```
Marketing_Data_Platform/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                     pull request validation
│   │   └── deploy.yml                 staging, then production
│   └── pull_request_template.md
├── docs/
│   ├── index.html                     generated static dbt documentation
│   ├── elementary_report.html
│   └── evidence/                      test records, indexed in its own README
├── infra/
│   └── unity_catalog_grants.sql       permissions for the service principal
├── marketing_data_platform/           the dbt project
│   ├── dbt_project.yml
│   ├── profiles.yml                   targets: dev, ci, staging, production
│   ├── packages.yml
│   ├── macros/
│   │   ├── generate_database_name.sql
│   │   ├── generate_schema_name.sql
│   │   └── drop_ci_schema.sql
│   ├── models/
│   │   ├── staging/{facebook,snapchat}/
│   │   ├── intermediate/{facebook,snapchat,marketing}/
│   │   ├── marts/{fact,dim,reporting}/
│   │   └── overview.md
│   └── tests/singular/                spend reconciliation tests
├── .env.template
├── pyproject.toml
├── uv.lock
└── README.md
```