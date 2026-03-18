CREATE OR REPLACE PACKAGE BODY pkg_dynamic_loader AS
    /*
     * PKG_DYNAMIC_LOADER Body
     * HIGH RISK: Multiple EXECUTE IMMEDIATE patterns
     * AI ANALYSIS FLAG: Target table names are runtime variables.
     * Static lineage extraction is NOT possible from this package.
     * Requires manual reverse-engineering during migration.
     */

    -- -------------------------------------------------------
    -- load_to_partition
    -- Dynamically routes INSERT into a partition based on
    -- runtime p_partition_key value (e.g., country_code)
    -- *** EXECUTE IMMEDIATE - HIGH COMPLEXITY ***
    -- -------------------------------------------------------
    PROCEDURE load_to_partition (
        p_target_table  IN VARCHAR2,
        p_partition_key IN VARCHAR2,
        p_load_date     IN DATE
    ) IS
        v_sql       VARCHAR2(4000);
        v_partition VARCHAR2(100);
        v_count     NUMBER;
    BEGIN
        -- Dynamically determine the partition name
        v_partition := 'P_' || UPPER(p_partition_key) || '_'
                       || TO_CHAR(p_load_date, 'YYYYMM');

        -- Build dynamic INSERT statement at runtime
        -- WARNING: p_target_table is a runtime parameter - lineage unknown statically
        v_sql := 'INSERT INTO ' || p_target_table ||
                 ' PARTITION (' || v_partition || ')' ||
                 ' SELECT s.settlement_id, ' ||
                 '        c.cust_sk, ' ||
                 '        pol.policy_sk, ' ||
                 '        s.settlement_date, ' ||
                 '        s.amount, ' ||
                 '        s.currency_code, ' ||
                 '        s.settlement_type, ' ||
                 '        s.reference_no, ' ||
                 '        :1 ' ||
                 ' FROM   SETTLEMENT_STG s ' ||
                 ' JOIN   CUST_DIM c   ON c.customer_id = (SELECT customer_id FROM POLICY_DIM WHERE policy_id = s.policy_id AND is_current = ''Y'') AND c.is_current = ''Y'' ' ||
                 ' JOIN   POLICY_DIM pol ON pol.policy_id = s.policy_id AND pol.is_current = ''Y'' ' ||
                 ' WHERE  s.load_date = :2';

        EXECUTE IMMEDIATE v_sql USING p_load_date, p_load_date;

        -- Count rows affected using dynamic SQL
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_table ||
                          ' WHERE load_date = :1'
                          INTO v_count
                          USING p_load_date;

        DBMS_OUTPUT.PUT_LINE('Loaded ' || v_count || ' rows into ' || p_target_table);

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR in load_to_partition: ' || SQLERRM);
            RAISE;
    END load_to_partition;

    -- -------------------------------------------------------
    -- rebuild_indexes
    -- Dynamically rebuilds all indexes on a given table
    -- *** EXECUTE IMMEDIATE loop - HIGH COMPLEXITY ***
    -- -------------------------------------------------------
    PROCEDURE rebuild_indexes (
        p_table_name IN VARCHAR2
    ) IS
        v_sql VARCHAR2(1000);

        CURSOR c_indexes IS
            SELECT index_name
            FROM   user_indexes
            WHERE  table_name = UPPER(p_table_name)
              AND  status     = 'UNUSABLE';
    BEGIN
        FOR r_idx IN c_indexes LOOP
            v_sql := 'ALTER INDEX ' || r_idx.index_name || ' REBUILD ONLINE';
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE('Rebuilt index: ' || r_idx.index_name);
        END LOOP;
    END rebuild_indexes;

    -- -------------------------------------------------------
    -- truncate_staging
    -- Truncates a staging table by name (runtime parameter)
    -- *** EXECUTE IMMEDIATE - HIGH COMPLEXITY ***
    -- -------------------------------------------------------
    PROCEDURE truncate_staging (
        p_stage_table IN VARCHAR2
    ) IS
    BEGIN
        -- Validate table name to prevent SQL injection (basic guard)
        IF p_stage_table NOT LIKE '%STG%' THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Security violation: truncate only allowed on staging tables. Got: '
                || p_stage_table);
        END IF;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || p_stage_table;
        DBMS_OUTPUT.PUT_LINE('Truncated: ' || p_stage_table);
    END truncate_staging;

END pkg_dynamic_loader;
/
