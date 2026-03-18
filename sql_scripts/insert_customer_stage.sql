-- ============================================================
-- insert_customer_stage.sql
-- Called by: load_customer_daily.ksh
-- Variables passed from shell: &1=LOAD_DATE, &2=SOURCE_SYSTEM
-- Complexity: LOW - standard INSERT..SELECT, ANSI SQL
-- ============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;

DEFINE LOAD_DATE    = &1
DEFINE SOURCE_SYS   = &2

-- Log start
PROMPT Loading CUST_RAW_STG for date &&LOAD_DATE from &&SOURCE_SYS ...

-- Truncate staging for the given load date before reload
DELETE FROM CUST_RAW_STG
WHERE  load_date    = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
  AND  source_system = '&&SOURCE_SYS';

COMMIT;

-- Insert incoming customer data into staging
-- In production this would be an external table or DB link feed
INSERT INTO CUST_RAW_STG (
    customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    address_line1,
    city,
    country_code,
    load_date,
    source_system,
    rec_status
)
SELECT
    src.customer_id,
    src.first_name,
    src.last_name,
    src.date_of_birth,
    src.email,
    src.phone,
    src.address_line1,
    src.city,
    src.country_code,
    TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD'),
    '&&SOURCE_SYS',
    'N'
FROM   CUST_FEED_EXT src          -- External table (flat file feed)
WHERE  src.feed_date = TO_DATE('&&LOAD_DATE', 'YYYY-MM-DD')
  AND  src.source_system = '&&SOURCE_SYS';

COMMIT;

PROMPT Staging load complete. &&SQL.ROWCOUNT rows inserted.

EXIT 0;
