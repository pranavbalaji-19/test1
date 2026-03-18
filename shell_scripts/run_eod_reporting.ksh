#!/bin/ksh
# ============================================================
# run_eod_reporting.ksh
# Description : End-of-day reporting wrapper. Calls regulatory
#               report generation PL/SQL and summary SQL.
# Called by   : UC4 Job EOD_REPORTING (JOB_EOD_REPORTING.xml)
# Arguments   : $1=REPORT_DATE, $2=ENV
# Complexity  : LOW - simple sequential execution, minimal branching
# ============================================================

set -u

REPORT_DATE=$1
ENV=$2

LOG_DIR=/opt/datawarehouse/logs
LOG_FILE=${LOG_DIR}/run_eod_reporting_${REPORT_DATE}.log
SCRIPT_DIR=/opt/datawarehouse/sql_scripts

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${LOG_FILE}
}

if [ "$ENV" = "PROD" ]; then
    ORACLE_CONN="dw_user/dw_pass@DWPROD"
else
    ORACLE_CONN="dw_user_uat/dw_pass_uat@DWUAT"
fi

log "===== START: run_eod_reporting.ksh REPORT_DATE=${REPORT_DATE} ====="

# ============================================================
# STEP 1: Generate regulatory aggregation via PL/SQL
# ============================================================
log "Calling pkg_regulatory_report.generate_daily_report ..."

sqlplus -s ${ORACLE_CONN} << EOF >> ${LOG_FILE} 2>&1
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
    v_rows NUMBER;
BEGIN
    pkg_regulatory_report.generate_daily_report(
        p_report_date => TO_DATE('${REPORT_DATE}','YYYY-MM-DD'),
        p_rows_out    => v_rows
    );
    DBMS_OUTPUT.PUT_LINE('Report rows: ' || v_rows);
END;
/
EXIT SQL.SQLCODE;
EOF

RPT_RC=$?
if [ $RPT_RC -ne 0 ]; then
    log "ERROR: Regulatory report generation failed (RC=${RPT_RC})"
    exit 2
fi

# ============================================================
# STEP 2: Run daily summary SQL (ANSI / BQMS auto-convertible)
# Calls: sql_scripts/generate_daily_summary.sql
# Passes: &1=REPORT_DATE
# ============================================================
log "Running generate_daily_summary.sql ..."

sqlplus -s ${ORACLE_CONN} @${SCRIPT_DIR}/generate_daily_summary.sql \
    "${REPORT_DATE}" \
    >> ${LOG_FILE} 2>&1

SUM_RC=$?
if [ $SUM_RC -ne 0 ]; then
    log "WARNING: Daily summary script failed (RC=${SUM_RC}). Non-fatal."
fi

log "===== END: run_eod_reporting.ksh SUCCESS ====="
exit 0
