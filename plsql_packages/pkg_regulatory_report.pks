CREATE OR REPLACE PACKAGE pkg_regulatory_report AS
    /*
     * PKG_REGULATORY_REPORT
     * Generates REGULATORY_REPORT_AGG from SETTLEMENT_FACT
     * Also uses DBMS_SCHEDULER for scheduling (Oracle-proprietary)
     *
     * Complexity: MIXED
     *   - Aggregation logic: MEDIUM (standard GROUP BY)
     *   - DBMS_SCHEDULER usage: INCOMPATIBLE / REDESIGN REQUIRED
     *     (Must be replaced by Cloud Composer DAG scheduling)
     */

    PROCEDURE generate_daily_report (
        p_report_date   IN DATE,
        p_rows_out      OUT NUMBER
    );

    PROCEDURE schedule_daily_job;     -- Uses DBMS_SCHEDULER - INCOMPATIBLE

END pkg_regulatory_report;
/
