-- ============================================================
-- generate_daily_summary.sql
-- Called by: run_eod_reporting.ksh
-- Variables: &1=REPORT_DATE
-- Complexity: LOW - plain ANSI SQL GROUP BY aggregation
-- Route: BQMS auto-convertible
-- ============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;

DEFINE REPORT_DATE = &1

PROMPT Generating daily settlement summary for &&REPORT_DATE ...

-- Simple aggregation - fully ANSI SQL, BQMS auto-convertible
SELECT
    cd.country_code,
    pd.product_code,
    sf.currency_code,
    COUNT(sf.settlement_sk)     AS total_count,
    SUM(sf.amount)              AS total_amount,
    MIN(sf.amount)              AS min_amount,
    MAX(sf.amount)              AS max_amount,
    AVG(sf.amount)              AS avg_amount
FROM   SETTLEMENT_FACT sf
JOIN   CUST_DIM   cd ON cd.cust_sk   = sf.cust_sk
                     AND cd.is_current = 'Y'
JOIN   POLICY_DIM pd ON pd.policy_sk = sf.policy_sk
                     AND pd.is_current = 'Y'
WHERE  sf.settlement_date = TO_DATE('&&REPORT_DATE', 'YYYY-MM-DD')
GROUP  BY cd.country_code,
          pd.product_code,
          sf.currency_code
ORDER  BY cd.country_code, pd.product_code;

EXIT 0;
