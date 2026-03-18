-- ============================================================
-- insert_policy_stage.sql
-- Called by: load_policy_daily.ksh
-- Variables: &1=LOAD_DATE, &2=SOURCE_SYSTEM, &3=PRODUCT_FILTER
-- Complexity: LOW - parameterized ANSI INSERT..SELECT
-- ============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;

DEFINE LOAD_DATE       = &1
DEFINE SOURCE_SYS      = &2
DEFINE PRODUCT_FILTER  = &3

PROMPT Loading POLICY_RAW_STG for &&LOAD_DATE / &&SOURCE_SYS / product=&&PRODUCT_FILTER

DELETE FROM POLICY_RAW_STG
WHERE  load_date     = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
  AND  source_system = '&&SOURCE_SYS';

COMMIT;

INSERT INTO POLICY_RAW_STG (
    policy_id,
    customer_id,
    product_code,
    start_date,
    end_date,
    premium_amount,
    currency_code,
    status,
    load_date,
    source_system,
    rec_status
)
SELECT
    pf.policy_id,
    pf.customer_id,
    pf.product_code,
    pf.start_date,
    pf.end_date,
    pf.premium_amount,
    pf.currency_code,
    pf.status,
    TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD'),
    '&&SOURCE_SYS',
    'N'
FROM   POLICY_FEED_EXT pf
WHERE  pf.feed_date     = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
  AND  pf.source_system = '&&SOURCE_SYS'
  AND  (pf.product_code = '&&PRODUCT_FILTER' OR '&&PRODUCT_FILTER' = 'ALL');

COMMIT;

PROMPT Policy staging complete.
EXIT 0;
