# Evidence

Test records for the claims made about the Marketing Data Platform.

| Folder | What it shows |
|---|---|
| `lineage/` | The lineage graph from the generated dbt docs |
| `genie/` | An AI agent answering marketing questions from the model, checked against the raw data |
| `elementary/` | Elementary observability catching a schema change |
| `service_principal/` | The pipeline building under a service principal's identity, not a person's |

## Lineage

| File | Contents |
|---|---|
| `lineage/lineage_graph_full.png` | Lineage graph from the generated dbt docs, from raw sources to the two consumers |

![Lineage graph](lineage/lineage_graph_full.png)

## Genie test

The final model, `mart_marketing_performance`, was put behind a Databricks Genie space to
test whether an AI agent can answer marketing questions correctly from the model's names
and documentation alone.

| File | Contents |
|---|---|
| `genie/genie_test_01_initial_run.pdf` | First run: three questions and Genie's answers |
| `genie/genie_test_02_after_instruction_fix.pdf` | Retest after adding an instruction on like-for-like comparisons |
| `genie/genie_ground_truth_check.md` | Each answer checked against figures recomputed from the raw CSV files |

### How the test was run

1. The table and column descriptions from dbt were stored with the table in Unity Catalog.
2. A Genie space was created over `mart_marketing_performance` only, with instructions
   stating the rules consumers must follow (group spend by currency, null means unknown,
   recompute ratios from sums).
3. Three questions were asked: Facebook spend in December 2025, the campaign with the most
   clicks, and a Facebook versus Snapchat spend comparison.
4. Each answer was checked against figures calculated directly from the raw files.

### Result

All figures matched the raw data. The one weakness is how the platform comparison is
worded, which is recorded in the ground truth file.

## Elementary observability

Elementary records every dbt test result and run in tables, and its report shows them over time.
A schema change test was added to the two staging stats models, the fact and the mart.
The full report is at `docs/elementary_report.html`.

| File | Contents |
|---|---|
| `elementary/elementary_01_dashboard_baseline.png` | Report dashboard before the demo, all tests healthy except two expected warnings |
| `elementary/elementary_02_schema_change_added_terminal.png` | dbt output when a demo column was added to `stg_facebook_ads_stats` |
| `elementary/elementary_03_schema_change_added_report.png` | The same detection shown in the Elementary report |
| `elementary/elementary_04_schema_change_removed.png` | Detection after removing the demo column |
| `elementary/elementary_05_dashboard_after_revert.png` | Report after the model returned to its original columns |

The demo column was added and removed in the dev schema only. It was never committed.

## Service principal

CI, staging and production authenticate as a Databricks service principal over OAuth, never a
personal access token. To check that the pipeline builds under its own identity, a CI-target
run created a test schema and the schema's owner was read back.

| File | Contents |
|---|---|
| `service_principal/sp_01_schema_owner_summary.png` | `DESCRIBE SCHEMA EXTENDED` on the test schema created by the CI-target run |
| `service_principal/sp_02_schema_owner_row.png` | The `Owner` row, showing the service principal's application ID and not a person |

### How the check was run

1. `dbt debug --target ci` connected as the service principal.
2. `dbt build --target ci --select stg_facebook_ads_stats` created `ci_development.sp_test`
   and built the model there. Seven of the eight project tests passed.
3. The eighth, an Elementary schema change test, needs Elementary's tables and a fresh schema
   has none. CI excludes those tests for that reason.
4. `DESCRIBE SCHEMA EXTENDED` showed the service principal's application ID as the owner.
5. The test schemas were dropped afterwards.

### Result

The pipeline authenticates, creates its own schemas, reads raw data and writes models under the
service principal's identity. The grants it was given are in `infra/unity_catalog_grants.sql`.