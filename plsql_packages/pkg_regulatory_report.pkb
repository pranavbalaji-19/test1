CREATE OR REPLACE PACKAGE BODY pkg_regulatory_report AS
    /*
     * PKG_REGULATORY_REPORT Body
     */

    -- -------------------------------------------------------
    -- generate_daily_report
    -- Aggregates SETTLEMENT_FACT into REGULATORY_REPORT_AGG
    -- Complexity: MEDIUM - standard GROUP BY aggregation
    -- -------------------------------------------------------
    PROCEDURE generate_daily_report (
        p_report_date   IN DATE,
        p_rows_out      OUT NUMBER
    ) IS
        v_rows NUMBER := 0;
    BEGIN
        -- Delete any existing report for this date (idempotent)
        DELETE FROM REGULATORY_REPORT_AGG
        WHERE  report_date = p_report_date;

        -- Aggregate settlements by country and product
        INSERT INTO REGULATORY_REPORT_AGG (
            report_date,
            country_code,
            product_code,
            total_settlements,
            total_amount,
            avg_premium,
            currency_code,
            generated_dt
        )
        SELECT sf.settlement_date                   AS report_date,
               cd.country_code,
               pd.product_code,
               COUNT(sf.settlement_sk)              AS total_settlements,
               SUM(sf.amount)                       AS total_amount,
               AVG(pd.premium_amount)               AS avg_premium,
               sf.currency_code,
               SYSDATE                              AS generated_dt
        FROM   SETTLEMENT_FACT sf
        JOIN   CUST_DIM   cd ON cd.cust_sk   = sf.cust_sk
        JOIN   POLICY_DIM pd ON pd.policy_sk = sf.policy_sk
        WHERE  sf.settlement_date = p_report_date
          AND  cd.is_current      = 'Y'
          AND  pd.is_current      = 'Y'
        GROUP  BY sf.settlement_date,
                  cd.country_code,
                  pd.product_code,
                  sf.currency_code;

        v_rows := SQL%ROWCOUNT;
        COMMIT;

        p_rows_out := v_rows;
        DBMS_OUTPUT.PUT_LINE('Regulatory report generated: ' || v_rows || ' rows.');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END generate_daily_report;

    -- -------------------------------------------------------
    -- schedule_daily_job
    -- *** ORACLE-PROPRIETARY: DBMS_SCHEDULER ***
    -- *** REDESIGN REQUIRED: Replace with Cloud Composer DAG ***
    -- This procedure creates an Oracle internal scheduler job.
    -- BigQuery / GCP has no equivalent. Migration requires
    -- replacing this with an Airflow DAG trigger in Cloud Composer.
    -- -------------------------------------------------------
    PROCEDURE schedule_daily_job IS
    BEGIN
        DBMS_SCHEDULER.CREATE_JOB (
            job_name        => 'REGULATORY_DAILY_RPT',
            job_type        => 'STORED_PROCEDURE',
            job_action      => 'pkg_regulatory_report.generate_daily_report',
            start_date      => SYSTIMESTAMP,
            repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
            enabled         => TRUE,
            comments        => 'Daily regulatory report aggregation - 02:00 UTC'
        );
        DBMS_OUTPUT.PUT_LINE('Scheduled job REGULATORY_DAILY_RPT created.');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -27477 THEN
                -- Job already exists, drop and recreate
                DBMS_SCHEDULER.DROP_JOB('REGULATORY_DAILY_RPT', TRUE);
                DBMS_SCHEDULER.CREATE_JOB (
                    job_name        => 'REGULATORY_DAILY_RPT',
                    job_type        => 'STORED_PROCEDURE',
                    job_action      => 'pkg_regulatory_report.generate_daily_report',
                    start_date      => SYSTIMESTAMP,
                    repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
                    enabled         => TRUE
                );
            ELSE
                RAISE;
            END IF;
    END schedule_daily_job;

END pkg_regulatory_report;
/
