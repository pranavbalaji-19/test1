CREATE OR REPLACE PACKAGE pkg_customer_hist AS
    /*
     * PKG_CUSTOMER_HIST
     * Manages SCD Type 2 historization for CUST_DIM
     * Source: CUST_RAW_STG -> Target: CUST_DIM
     * Complexity: HIGH (custom valid_from/valid_to management)
     */

    PROCEDURE load_customer_dim (
        p_load_date     IN DATE,
        p_source_sys    IN VARCHAR2,
        p_rows_out      OUT NUMBER
    );

    PROCEDURE expire_old_records (
        p_customer_id   IN VARCHAR2,
        p_expire_date   IN DATE
    );

    FUNCTION get_current_cust_sk (
        p_customer_id   IN VARCHAR2
    ) RETURN NUMBER;

END pkg_customer_hist;
/
