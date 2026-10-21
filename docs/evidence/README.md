# Evidence

Test records for the claims made about the Marketing Data Platform.

## Lineage

| File | Contents |
|---|---|
| `lineage_graph_full.png` | Lineage graph from the generated dbt docs, from the raw sources to the two consumers |

![Lineage graph](lineage_graph_full.png)

## Genie test

The final model, `mart_marketing_performance`, was put behind a Databricks Genie space to
test whether an AI agent can answer marketing questions correctly from the model's names
and documentation alone.

| File | Contents |
|---|---|
| `genie_test_01_initial_run.pdf` | First run: three questions and Genie's answers |
| `genie_test_02_after_instruction_fix.pdf` | Retest after adding an instruction on like-for-like comparisons |
| `genie_ground_truth_check.md` | Each answer checked against figures recomputed from the raw CSV files |

## How the test was run

1. The table and column descriptions from dbt were stored with the table in Unity Catalog.
2. A Genie space was created over `mart_marketing_performance` only, with instructions
   stating the rules consumers must follow (group spend by currency, null means unknown,
   recompute ratios from sums).
3. Three questions were asked: Facebook spend in December 2025, the campaign with the most
   clicks, and a Facebook versus Snapchat spend comparison.
4. Each answer was checked against figures calculated directly from the raw files.

## Result

All figures matched the raw data. The one weakness is how the platform comparison is
worded, which is recorded in the ground truth file.