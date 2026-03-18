-- ============================================================
-- insert_settlement_stage.sql
-- Called by: load_settlement_daily.ksh
-- Variables: &1=LOAD_DATE, &2=TARGET_TABLE, &3=CURRENCY_CODE
-- Complexity: MEDIUM - multi-table join (3 tables), parameterized target
-- ============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;

DEFINE LOAD_DATE      = &1
DEFINE TARGET_TABLE   = &2
DEFINE CURRENCY       = &3

PROMPT Loading &&TARGET_TABLE for date &&LOAD_DATE currency &&CURRENCY

-- Multi-table join: SETTLEMENT_FEED_EXT + POLICY_RAW_STG + CUST_RAW_STG
-- Enriches the settlement feed with customer and policy context
INSERT INTO &&TARGET_TABLE (
    settlement_id,
    policy_id,
    settlement_date,
    amount,
    currency_code,
    settlement_type,
    reference_no,
    load_date
)
SELECT
    sf.settlement_id,
    sf.policy_id,
    sf.settlement_date,
    CASE
        WHEN '&&CURRENCY' = 'USD' THEN sf.amount * er.usd_rate
        WHEN '&&CURRENCY' = 'EUR' THEN sf.amount * er.eur_rate
        ELSE sf.amount
    END                         AS amount,
    '&&CURRENCY'                AS currency_code,
    sf.settlement_type,
    sf.reference_no,
    TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD') AS load_date
FROM   SETTLEMENT_FEED_EXT sf
JOIN   POLICY_RAW_STG      prs ON prs.policy_id   = sf.policy_id
                               AND prs.load_date   = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
JOIN   CUST_RAW_STG        crs ON crs.customer_id  = prs.customer_id
                               AND crs.load_date   = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
LEFT JOIN EXCHANGE_RATE_REF er ON er.rate_date     = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
                               AND er.base_currency = sf.currency_code
WHERE  sf.settlement_date = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD');

COMMIT;

PROMPT Settlement staging complete.
EXIT 0;
