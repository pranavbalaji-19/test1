CREATE OR REPLACE PACKAGE pkg_settlement_load AS
    /*
     * PKG_SETTLEMENT_LOAD
     * Loads SETTLEMENT_FACT from SETTLEMENT_STG
     * joining CUST_DIM and POLICY_DIM surrogate keys
     * Complexity: MEDIUM - standard PL/SQL loops, no dynamic SQL
     */

    PROCEDURE load_settlement_fact (
        p_load_date  IN DATE,
        p_rows_out   OUT NUMBER
    );

    PROCEDURE reconcile_amounts (
        p_load_date  IN DATE,
        p_variance   OUT NUMBER
    );

END pkg_settlement_load;
/
