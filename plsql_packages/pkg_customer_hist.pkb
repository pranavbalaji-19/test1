CREATE OR REPLACE PACKAGE BODY pkg_customer_hist AS
    /*
     * PKG_CUSTOMER_HIST Body
     * SCD Type 2 historization with manual valid_from/valid_to management
     * Complexity: HIGH - deeply nested historization across multiple tables
     */

    -- -------------------------------------------------------
    -- Private helper: log job execution to audit table
    -- -------------------------------------------------------
    PROCEDURE log_audit (
        p_job_name      IN VARCHAR2,
        p_status        IN VARCHAR2,
        p_rows          IN NUMBER,
        p_msg           IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO JOB_AUDIT_LOG (
            job_name, script_name, start_time, end_time,
            status, rows_processed, error_msg, load_date
        ) VALUES (
            p_job_name, 'pkg_customer_hist.pkb', SYSDATE, SYSDATE,
            p_status, p_rows, p_msg, TRUNC(SYSDATE)
        );
        COMMIT;
    END log_audit;

    -- -------------------------------------------------------
    -- expire_old_records
    -- Closes the current active record for a given customer
    -- by setting valid_to and is_current = 'N'
    -- -------------------------------------------------------
    PROCEDURE expire_old_records (
        p_customer_id   IN VARCHAR2,
        p_expire_date   IN DATE
    ) IS
    BEGIN
        UPDATE CUST_DIM
        SET    valid_to   = p_expire_date - 1,
               is_current = 'N'
        WHERE  customer_id = p_customer_id
          AND  is_current  = 'Y'
          AND  valid_to    = TO_DATE('9999-12-31', 'YYYY-MM-DD');
    END expire_old_records;

    -- -------------------------------------------------------
    -- get_current_cust_sk
    -- Returns the surrogate key for the active record
    -- -------------------------------------------------------
    FUNCTION get_current_cust_sk (
        p_customer_id IN VARCHAR2
    ) RETURN NUMBER IS
        v_sk NUMBER;
    BEGIN
        SELECT cust_sk
        INTO   v_sk
        FROM   CUST_DIM
        WHERE  customer_id = p_customer_id
          AND  is_current  = 'Y'
          AND  ROWNUM = 1;
        RETURN v_sk;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_current_cust_sk;

    -- -------------------------------------------------------
    -- load_customer_dim  (MAIN PROCEDURE)
    -- Full SCD Type 2 merge logic
    -- -------------------------------------------------------
    PROCEDURE load_customer_dim (
        p_load_date     IN DATE,
        p_source_sys    IN VARCHAR2,
        p_rows_out      OUT NUMBER
    ) IS
        v_rows_inserted NUMBER := 0;
        v_rows_updated  NUMBER := 0;
        v_existing_sk   NUMBER;

        -- Cursor over staged records for this load date
        CURSOR c_staged IS
            SELECT stg_id,
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
                   source_system
            FROM   CUST_RAW_STG
            WHERE  load_date   = p_load_date
              AND  source_system = p_source_sys
              AND  rec_status  = 'N'
            ORDER BY customer_id;

        -- Nested cursor to check if the incoming record differs from current
        CURSOR c_existing (p_cid VARCHAR2) IS
            SELECT cust_sk,
                   first_name,
                   last_name,
                   date_of_birth,
                   email,
                   phone,
                   address_line1,
                   city,
                   country_code
            FROM   CUST_DIM
            WHERE  customer_id = p_cid
              AND  is_current  = 'Y';

        r_existing c_existing%ROWTYPE;
        v_changed  BOOLEAN := FALSE;

    BEGIN
        -- Outer loop: iterate every staged customer record
        FOR r_stg IN c_staged LOOP

            v_changed := FALSE;

            -- Inner loop: compare against existing current record
            OPEN c_existing(r_stg.customer_id);
            FETCH c_existing INTO r_existing;

            IF c_existing%FOUND THEN
                -- Check if any tracked attribute has changed
                IF    NVL(r_stg.first_name,    '~') <> NVL(r_existing.first_name,    '~')
                   OR NVL(r_stg.last_name,     '~') <> NVL(r_existing.last_name,     '~')
                   OR NVL(r_stg.email,         '~') <> NVL(r_existing.email,         '~')
                   OR NVL(r_stg.phone,         '~') <> NVL(r_existing.phone,         '~')
                   OR NVL(r_stg.address_line1, '~') <> NVL(r_existing.address_line1, '~')
                   OR NVL(r_stg.city,          '~') <> NVL(r_existing.city,          '~')
                   OR NVL(r_stg.country_code,  '~') <> NVL(r_existing.country_code,  '~')
                THEN
                    v_changed := TRUE;
                END IF;

                IF v_changed THEN
                    -- Step 1: Expire the existing current record
                    expire_old_records(r_stg.customer_id, r_stg.load_date);
                    v_rows_updated := v_rows_updated + 1;

                    -- Step 2: Insert new version as current
                    INSERT INTO CUST_DIM (
                        customer_id, first_name, last_name, date_of_birth,
                        email, phone, address_line1, city, country_code,
                        valid_from, valid_to, is_current, created_by, created_dt
                    ) VALUES (
                        r_stg.customer_id, r_stg.first_name, r_stg.last_name,
                        r_stg.date_of_birth, r_stg.email, r_stg.phone,
                        r_stg.address_line1, r_stg.city, r_stg.country_code,
                        r_stg.load_date,
                        TO_DATE('9999-12-31', 'YYYY-MM-DD'),
                        'Y',
                        p_source_sys,
                        SYSDATE
                    );
                    v_rows_inserted := v_rows_inserted + 1;
                END IF;

            ELSE
                -- New customer: insert first-time record
                INSERT INTO CUST_DIM (
                    customer_id, first_name, last_name, date_of_birth,
                    email, phone, address_line1, city, country_code,
                    valid_from, valid_to, is_current, created_by, created_dt
                ) VALUES (
                    r_stg.customer_id, r_stg.first_name, r_stg.last_name,
                    r_stg.date_of_birth, r_stg.email, r_stg.phone,
                    r_stg.address_line1, r_stg.city, r_stg.country_code,
                    r_stg.load_date,
                    TO_DATE('9999-12-31', 'YYYY-MM-DD'),
                    'Y',
                    p_source_sys,
                    SYSDATE
                );
                v_rows_inserted := v_rows_inserted + 1;
            END IF;

            CLOSE c_existing;

            -- Mark staged record as processed
            UPDATE CUST_RAW_STG
            SET    rec_status = 'P'
            WHERE  stg_id = r_stg.stg_id;

        END LOOP;

        p_rows_out := v_rows_inserted + v_rows_updated;
        COMMIT;

        log_audit('PKG_CUSTOMER_HIST.LOAD_CUSTOMER_DIM', 'SUCCESS', p_rows_out);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            log_audit('PKG_CUSTOMER_HIST.LOAD_CUSTOMER_DIM', 'FAILED', 0, SQLERRM);
            RAISE;
    END load_customer_dim;

END pkg_customer_hist;
/
