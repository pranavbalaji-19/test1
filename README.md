# Legacy DW Repository — Synthetic Test Dataset

## Purpose
This repository is a **synthetic legacy data warehouse** simulating an enterprise banking/insurance
environment. It is designed to test an automated migration analysis tool (DataStreak Discovery Engine)
covering all aspects of discovery: variable resolution, lineage graphing, complexity scoring,
Ab Initio mapping, UC4 orchestration parsing, and dependency wave generation.

---

## Repository Structure

```
legacy_repo/
├── ddl/                            # Oracle CREATE TABLE scripts
│   ├── 01_create_staging_tables.sql        # Staging tables (CUST_RAW_STG, POLICY_RAW_STG, SETTLEMENT_STG)
│   ├── 02_create_dimension_tables.sql      # SCD Type 2 dims (CUST_DIM, POLICY_DIM)
│   ├── 03_create_fact_and_analytical_tables.sql  # SETTLEMENT_FACT, REGULATORY_REPORT_AGG
│   └── 04_product_hierarchy_incompatible.sql     # CONNECT BY — REDESIGN REQUIRED
│
├── shell_scripts/                  # KornShell (.ksh) orchestration scripts
│   ├── load_customer_daily.ksh     # $1=LOAD_DATE $2=SOURCE_SYS $3=ENV | retry loop | PL/SQL call
│   ├── load_policy_daily.ksh       # Conditional branching by PRODUCT_CODE and ENV
│   ├── load_settlement_daily.ksh   # Dependency check + retry + reconciliation
│   └── run_eod_reporting.ksh       # Simple EOD wrapper (low complexity)
│
├── sql_scripts/                    # SQL*Plus scripts called by shell scripts
│   ├── insert_customer_stage.sql   # &1=LOAD_DATE &2=SOURCE_SYS substitution variables
│   ├── insert_policy_stage.sql     # &1=LOAD_DATE &2=SOURCE_SYS &3=PRODUCT_FILTER
│   ├── insert_settlement_stage.sql # 3-table JOIN + &2=TARGET_TABLE (dynamic target)
│   └── generate_daily_summary.sql  # ANSI GROUP BY — BQMS auto-convertible (LOW complexity)
│
├── plsql_packages/                 # Oracle PL/SQL Package specs (.pks) and bodies (.pkb)
│   ├── pkg_customer_hist.pks/pkb   # SCD Type 2 historization (HIGH complexity)
│   ├── pkg_policy_hist.pkb         # SCD Type 2 for policies (HIGH complexity)
│   ├── pkg_settlement_load.pks/pkb # Standard cursor loop fact load (MEDIUM complexity)
│   ├── pkg_dynamic_loader.pks/pkb  # EXECUTE IMMEDIATE dynamic SQL (HIGH / flagged)
│   └── pkg_regulatory_report.pks/pkb  # DBMS_SCHEDULER (INCOMPATIBLE / redesign)
│
├── abinitio/                       # Ab Initio DML and XFR files
│   ├── customer_feed.dml           # Record layout schemas (INPUT, OUTPUT, AGG)
│   ├── customer_transform.xfr      # REFORMAT component → maps to SELECT/CASE
│   ├── customer_rollup.xfr         # ROLLUP component → maps to GROUP BY
│   └── settlement_agg.xfr          # Combined REFORMAT + ROLLUP
│
└── uc4_jobs/                       # Automic UC4 job export XMLs
    ├── JOB_CUST_DAILY_LOAD.xml     # Job A — time trigger, starts chain at 01:00 UTC
    ├── JOB_POLICY_DAILY_LOAD.xml   # Job B — triggered by Job A success
    ├── JOB_SETTLEMENT_DAILY_LOAD.xml  # Job C — triggered by Job B, conditional branch
    └── JOB_EOD_REPORTING.xml       # Job D — triggered by Job C exit=0 only (terminal)
```

---

## End-to-End Lineage Chain

The primary pipeline chain flows as follows:

```
UC4 Trigger (01:00 UTC)
    └─► JOB_CUST_DAILY_LOAD.xml
            └─► load_customer_daily.ksh  [$1=LOAD_DATE, $2=SOURCE_SYS, $3=ENV]
                    ├─► insert_customer_stage.sql  [&1=LOAD_DATE, &2=SOURCE_SYS]
                    │       └─► CUST_RAW_STG  (staging table)
                    └─► pkg_customer_hist.load_customer_dim
                            └─► CUST_DIM  (SCD Type 2 dimension)

    └─► JOB_POLICY_DAILY_LOAD.xml  (on CUST success)
            └─► load_policy_daily.ksh  [$1=LOAD_DATE, $2=SOURCE_SYS, $3=PRODUCT, $4=ENV]
                    ├─► insert_policy_stage.sql  [&1=LOAD_DATE, &2=SOURCE_SYS, &3=FILTER]
                    │       └─► POLICY_RAW_STG  (staging table)
                    └─► pkg_policy_hist.load_policy_dim
                            └─► POLICY_DIM  (SCD Type 2 dimension)

    └─► JOB_SETTLEMENT_DAILY_LOAD.xml  (on POLICY success)
            └─► load_settlement_daily.ksh  [$1=LOAD_DATE, $2=CURRENCY, $3=ENV]
                    ├─► insert_settlement_stage.sql  [&1=LOAD_DATE, &2=TARGET_TABLE, &3=CURRENCY]
                    │       ├─► CUST_RAW_STG  (join source)
                    │       ├─► POLICY_RAW_STG  (join source)
                    │       └─► SETTLEMENT_STG  (staging target)
                    └─► pkg_settlement_load.load_settlement_fact
                            ├─► CUST_DIM  (lookup)
                            ├─► POLICY_DIM  (lookup)
                            └─► SETTLEMENT_FACT  (fact table)

    └─► JOB_EOD_REPORTING.xml  (ONLY if Settlement exit=0)
            └─► run_eod_reporting.ksh  [$1=REPORT_DATE, $2=ENV]
                    ├─► pkg_regulatory_report.generate_daily_report
                    │       ├─► SETTLEMENT_FACT  (source)
                    │       ├─► CUST_DIM  (join)
                    │       ├─► POLICY_DIM  (join)
                    │       └─► REGULATORY_REPORT_AGG  (final output)
                    └─► generate_daily_summary.sql  [&1=REPORT_DATE]
```

---

## Lineage Summary Table

| UC4 Job | Shell Script | SQL Script Called | Tables Read | PL/SQL Package | Output Table |
|---|---|---|---|---|---|
| JOB_CUST_DAILY_LOAD | load_customer_daily.ksh | insert_customer_stage.sql | CUST_FEED_EXT | pkg_customer_hist | CUST_DIM |
| JOB_POLICY_DAILY_LOAD | load_policy_daily.ksh | insert_policy_stage.sql | POLICY_FEED_EXT | pkg_policy_hist | POLICY_DIM |
| JOB_SETTLEMENT_DAILY_LOAD | load_settlement_daily.ksh | insert_settlement_stage.sql | CUST_RAW_STG, POLICY_RAW_STG, SETTLEMENT_FEED_EXT | pkg_settlement_load | SETTLEMENT_FACT |
| JOB_EOD_REPORTING | run_eod_reporting.ksh | generate_daily_summary.sql | SETTLEMENT_FACT, CUST_DIM, POLICY_DIM | pkg_regulatory_report | REGULATORY_REPORT_AGG |

---

## Complexity Coverage

| File | Complexity Tier | Key Pattern |
|---|---|---|
| generate_daily_summary.sql | LOW | ANSI GROUP BY — BQMS auto-convertible |
| insert_customer_stage.sql | LOW | Parameterised INSERT..SELECT |
| customer_transform.xfr | MEDIUM | Ab Initio REFORMAT → SELECT/CASE |
| customer_rollup.xfr | MEDIUM | Ab Initio ROLLUP → GROUP BY |
| pkg_settlement_load.pkb | MEDIUM | Standard PL/SQL cursor loop |
| load_policy_daily.ksh | MEDIUM | Conditional branching, ENV routing |
| pkg_customer_hist.pkb | HIGH | Nested SCD Type 2, valid_from/valid_to |
| pkg_policy_hist.pkb | HIGH | Nested SCD Type 2, multi-cursor |
| pkg_dynamic_loader.pkb | HIGH | EXECUTE IMMEDIATE, dynamic SQL |
| pkg_regulatory_report.pkb | INCOMPATIBLE | DBMS_SCHEDULER — redesign required |
| 04_product_hierarchy_incompatible.sql | INCOMPATIBLE | Oracle CONNECT BY — no BQ equivalent |

---

## Variable Substitution Coverage

| Shell Variable | Passed Into SQL As | SQL Script |
|---|---|---|
| `$1` (LOAD_DATE) | `&1` / `&&LOAD_DATE` | insert_customer_stage.sql |
| `$2` (SOURCE_SYS) | `&2` / `&&SOURCE_SYS` | insert_customer_stage.sql |
| `$1` (LOAD_DATE) | `&1` | insert_policy_stage.sql |
| `$3` (PRODUCT_FILTER) | `&3` / `&&PRODUCT_FILTER` | insert_policy_stage.sql |
| `$1` (LOAD_DATE) | `&1` | insert_settlement_stage.sql |
| `$2` (TARGET_TABLE) | `&2` / `&&TARGET_TABLE` | insert_settlement_stage.sql (dynamic target!) |
| `$3` (CURRENCY_CODE) | `&3` / `&&CURRENCY` | insert_settlement_stage.sql |
