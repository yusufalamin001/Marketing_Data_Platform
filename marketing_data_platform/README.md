# dbt project

This folder holds the dbt project for the Marketing Data Platform. The architecture,
decisions, setup steps and evidence are in the [main README](../README.md).

## Layout

| Folder | Contents |
|---|---|
| `models/staging` | One view per raw table, split by platform |
| `models/intermediate` | Per-platform joins (ephemeral) and the unified union |
| `models/marts` | `fact`, `dim` and `reporting` models |
| `macros` | Catalog and schema routing, and the CI schema cleanup |
| `tests/singular` | Spend reconciliation tests |

## Commands

Run from this folder:

    uv run --env-file ../.env dbt deps
    uv run --env-file ../.env dbt build