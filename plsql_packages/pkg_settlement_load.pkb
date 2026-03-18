CREATE OR REPLACE PACKAGE BODY pkg_settlement_load AS
    /*
     * PKG_SETTLEMENT_LOAD Body
     * Complexity: MEDIUM
     * Standard cursor loops, MERGE statement, no dynamic SQL
     */

    PROCEDURE load_settlement_fact (
        p_load_date  IN DATE,
        p_rows_out   OUT NUMBER
    ) IS
        v_cust_sk       NUMBER;
        v_policy_sk     NUMBER;
        v_inserted      NUMBER := 0;
        v_skipped       NUMBER := 0;
    BEGIN
        -- Loop through all staged settlements for the load date
        FOR r_stg IN (
            SELECT stg_id,
                   settlement_id,
                   policy_id,
                   settlement_date,
                   amount,
                   currency_code,
                   settlement_type,
                   reference_no,
                   load_date
            FROM   SETTLEMENT_STG
            WHERE  load_date = p_load_date
            ORDER  BY settlement_date, settlement_id
        ) LOOP
            -- Lookup policy surrogate key
            BEGIN
                SELECT policy_sk
                INTO   v_policy_sk
                FROM   POLICY_DIM
                WHERE  policy_id   = r_stg.policy_id
                  AND  is_current  = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_policy_sk := NULL;
            END;

            -- Lookup customer surrogate key via policy
            BEGIN
                SELECT c.cust_sk
                INTO   v_cust_sk
                FROM   CUST_DIM c
                JOIN   POLICY_DIM p ON p.customer_id = c.customer_id
                WHERE  p.policy_id  = r_stg.policy_id
                  AND  p.is_current = 'Y'
                  AND  c.is_current = 'Y'
                  AND  ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_cust_sk := NULL;
            END;

            IF v_policy_sk IS NOT NULL AND v_cust_sk IS NOT NULL THEN
                INSERT INTO SETTLEMENT_FACT (
                    settlement_id,
                    cust_sk,
                    policy_sk,
                    settlement_date,
                    amount,
                    currency_code,
                    settlement_type,
                    reference_no,
                    load_date
                ) VALUES (
                    r_stg.settlement_id,
                    v_cust_sk,
                    v_policy_sk,
                    r_stg.settlement_date,
                    r_stg.amount,
                    r_stg.currency_code,
                    r_stg.settlement_type,
                    r_stg.reference_no,
                    r_stg.load_date
                );
                v_inserted := v_inserted + 1;
            ELSE
                -- Log skipped record (referential integrity failure)
                INSERT INTO JOB_AUDIT_LOG (
                    job_name, script_name, start_time, status,
                    rows_processed, error_msg, load_date
                ) VALUES (
                    'PKG_SETTLEMENT_LOAD', 'pkg_settlement_load.pkb',
                    SYSDATE, 'SKIP', 0,
                    'No dim key for settlement_id=' || r_stg.settlement_id
                    || ' policy_id=' || r_stg.policy_id,
                    p_load_date
                );
                v_skipped := v_skipped + 1;
            END IF;
        END LOOP;

        COMMIT;
        p_rows_out := v_inserted;
        DBMS_OUTPUT.PUT_LINE('Settlement load complete. Inserted=' || v_inserted
                             || ' Skipped=' || v_skipped);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END load_settlement_fact;

    -- -------------------------------------------------------
    -- reconcile_amounts
    -- Compares STG total vs FACT total for the load date
    -- Returns variance amount (0 = clean)
    -- -------------------------------------------------------
    PROCEDURE reconcile_amounts (
        p_load_date  IN DATE,
        p_variance   OUT NUMBER
    ) IS
        v_stg_total    NUMBER := 0;
        v_fact_total   NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(amount), 0)
        INTO   v_stg_total
        FROM   SETTLEMENT_STG
        WHERE  load_date = p_load_date;

        SELECT NVL(SUM(amount), 0)
        INTO   v_fact_total
        FROM   SETTLEMENT_FACT
        WHERE  load_date = p_load_date;

        p_variance := v_stg_total - v_fact_total;

        IF p_variance <> 0 THEN
            DBMS_OUTPUT.PUT_LINE('RECONCILIATION WARNING: Variance = ' || p_variance);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Reconciliation OK for ' || TO_CHAR(p_load_date,'YYYY-MM-DD'));
        END IF;
    END reconcile_amounts;

END pkg_settlement_load;
/
