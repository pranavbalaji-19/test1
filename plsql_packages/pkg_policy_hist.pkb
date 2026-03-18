CREATE OR REPLACE PACKAGE pkg_policy_hist AS
    /*
     * PKG_POLICY_HIST
     * SCD Type 2 historization for POLICY_DIM
     * Mirrors pkg_customer_hist pattern for policies
     * Complexity: HIGH - nested historization across POLICY_DIM
     * Source: POLICY_RAW_STG -> Target: POLICY_DIM
     */

    PROCEDURE load_policy_dim (
        p_load_date   IN DATE,
        p_source_sys  IN VARCHAR2,
        p_product_cd  IN VARCHAR2 DEFAULT 'ALL',
        p_rows_out    OUT NUMBER
    );

    PROCEDURE expire_policy_records (
        p_policy_id   IN VARCHAR2,
        p_expire_date IN DATE
    );

    FUNCTION get_current_policy_sk (
        p_policy_id IN VARCHAR2
    ) RETURN NUMBER;

END pkg_policy_hist;
/

CREATE OR REPLACE PACKAGE BODY pkg_policy_hist AS

    PROCEDURE expire_policy_records (
        p_policy_id   IN VARCHAR2,
        p_expire_date IN DATE
    ) IS
    BEGIN
        UPDATE POLICY_DIM
        SET    valid_to   = p_expire_date - 1,
               is_current = 'N'
        WHERE  policy_id  = p_policy_id
          AND  is_current = 'Y'
          AND  valid_to   = TO_DATE('9999-12-31','YYYY-MM-DD');
    END expire_policy_records;

    FUNCTION get_current_policy_sk (
        p_policy_id IN VARCHAR2
    ) RETURN NUMBER IS
        v_sk NUMBER;
    BEGIN
        SELECT policy_sk INTO v_sk
        FROM   POLICY_DIM
        WHERE  policy_id   = p_policy_id
          AND  is_current  = 'Y'
          AND  ROWNUM = 1;
        RETURN v_sk;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END get_current_policy_sk;

    PROCEDURE load_policy_dim (
        p_load_date   IN DATE,
        p_source_sys  IN VARCHAR2,
        p_product_cd  IN VARCHAR2 DEFAULT 'ALL',
        p_rows_out    OUT NUMBER
    ) IS
        v_rows    NUMBER := 0;
        v_changed BOOLEAN := FALSE;

        CURSOR c_staged IS
            SELECT stg_id, policy_id, customer_id, product_code,
                   start_date, end_date, premium_amount,
                   currency_code, status, load_date
            FROM   POLICY_RAW_STG
            WHERE  load_date     = p_load_date
              AND  source_system = p_source_sys
              AND  rec_status    = 'N'
              AND  (product_code = p_product_cd OR p_product_cd = 'ALL')
            ORDER  BY policy_id;

        CURSOR c_existing (p_pid VARCHAR2) IS
            SELECT policy_sk, customer_id, product_code,
                   start_date, end_date, premium_amount,
                   currency_code, status
            FROM   POLICY_DIM
            WHERE  policy_id  = p_pid
              AND  is_current = 'Y';

        r_existing c_existing%ROWTYPE;

    BEGIN
        FOR r_stg IN c_staged LOOP
            v_changed := FALSE;
            OPEN c_existing(r_stg.policy_id);
            FETCH c_existing INTO r_existing;

            IF c_existing%FOUND THEN
                IF    NVL(r_stg.premium_amount, -1) <> NVL(r_existing.premium_amount, -1)
                   OR NVL(r_stg.status, '~')        <> NVL(r_existing.status, '~')
                   OR NVL(r_stg.end_date, SYSDATE)  <> NVL(r_existing.end_date, SYSDATE)
                THEN
                    v_changed := TRUE;
                END IF;

                IF v_changed THEN
                    expire_policy_records(r_stg.policy_id, r_stg.load_date);
                    INSERT INTO POLICY_DIM (
                        policy_id, customer_id, product_code, start_date, end_date,
                        premium_amount, currency_code, status,
                        valid_from, valid_to, is_current, created_by, created_dt
                    ) VALUES (
                        r_stg.policy_id, r_stg.customer_id, r_stg.product_code,
                        r_stg.start_date, r_stg.end_date, r_stg.premium_amount,
                        r_stg.currency_code, r_stg.status,
                        r_stg.load_date, TO_DATE('9999-12-31','YYYY-MM-DD'),
                        'Y', p_source_sys, SYSDATE
                    );
                    v_rows := v_rows + 1;
                END IF;
            ELSE
                INSERT INTO POLICY_DIM (
                    policy_id, customer_id, product_code, start_date, end_date,
                    premium_amount, currency_code, status,
                    valid_from, valid_to, is_current, created_by, created_dt
                ) VALUES (
                    r_stg.policy_id, r_stg.customer_id, r_stg.product_code,
                    r_stg.start_date, r_stg.end_date, r_stg.premium_amount,
                    r_stg.currency_code, r_stg.status,
                    r_stg.load_date, TO_DATE('9999-12-31','YYYY-MM-DD'),
                    'Y', p_source_sys, SYSDATE
                );
                v_rows := v_rows + 1;
            END IF;

            CLOSE c_existing;

            UPDATE POLICY_RAW_STG SET rec_status = 'P'
            WHERE stg_id = r_stg.stg_id;
        END LOOP;

        COMMIT;
        p_rows_out := v_rows;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; RAISE;
    END load_policy_dim;

END pkg_policy_hist;
/
