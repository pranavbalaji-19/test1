#!/bin/ksh
# ============================================================
# load_customer_daily.ksh
# Description : Loads customer data into staging and calls
#               PL/SQL historization package
# Called by   : UC4 Job CUST_DAILY_LOAD (uc4_jobs/JOB_CUST_DAILY.xml)
# Arguments   : $1=LOAD_DATE (YYYY-MM-DD), $2=SOURCE_SYSTEM, $3=ENV
# Complexity  : MEDIUM - retry logic, error handling, PL/SQL call
# ============================================================

set -u

# --- Argument validation ---
if [ $# -lt 3 ]; then
    echo "ERROR: Usage: $0 LOAD_DATE SOURCE_SYSTEM ENV"
    exit 1
fi

LOAD_DATE=$1
SOURCE_SYS=$2
ENV=$3
SCRIPT_NAME=$(basename $0)
LOG_DIR=/opt/datawarehouse/logs
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME%.ksh}_${LOAD_DATE}.log
MAX_RETRIES=3
RETRY_WAIT=60

ORACLE_SID_PROD=DWPROD
ORACLE_SID_UAT=DWUAT

# --- Environment routing ---
if [ "$ENV" = "PROD" ]; then
    ORACLE_CONN="dw_user/dw_pass@${ORACLE_SID_PROD}"
    PRODUCT_FILTER="ALL"
elif [ "$ENV" = "UAT" ]; then
    ORACLE_CONN="dw_user_uat/dw_pass_uat@${ORACLE_SID_UAT}"
    PRODUCT_FILTER="TEST_PROD"
else
    echo "ERROR: Unknown ENV=$ENV. Expected PROD or UAT." | tee -a ${LOG_FILE}
    exit 2
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${LOG_FILE}
}

log "===== START: ${SCRIPT_NAME} LOAD_DATE=${LOAD_DATE} SOURCE=${SOURCE_SYS} ENV=${ENV} ====="

# ============================================================
# STEP 1: Load customer staging (with retry loop)
# Calls: sql_scripts/insert_customer_stage.sql
# Passes: &1=LOAD_DATE &2=SOURCE_SYS
# ============================================================
ATTEMPT=0
STAGE_RC=1

while [ $ATTEMPT -lt $MAX_RETRIES ] && [ $STAGE_RC -ne 0 ]; do
    ATTEMPT=$((ATTEMPT + 1))
    log "Attempt ${ATTEMPT}/${MAX_RETRIES}: Running insert_customer_stage.sql"

    sqlplus -s ${ORACLE_CONN} @/opt/datawarehouse/sql_scripts/insert_customer_stage.sql \
        "${LOAD_DATE}" \
        "${SOURCE_SYS}" \
        >> ${LOG_FILE} 2>&1

    STAGE_RC=$?

    if [ $STAGE_RC -ne 0 ]; then
        log "WARNING: Staging load failed (RC=${STAGE_RC}). Waiting ${RETRY_WAIT}s before retry..."
        if [ $ATTEMPT -lt $MAX_RETRIES ]; then
            sleep ${RETRY_WAIT}
        fi
    fi
done

if [ $STAGE_RC -ne 0 ]; then
    log "ERROR: insert_customer_stage.sql failed after ${MAX_RETRIES} attempts. Aborting."
    exit 3
fi

log "Staging load successful."

# ============================================================
# STEP 2: Call PL/SQL historization package
# pkg_customer_hist.load_customer_dim
# ============================================================
log "Calling PL/SQL pkg_customer_hist.load_customer_dim ..."

sqlplus -s ${ORACLE_CONN} << EOF >> ${LOG_FILE} 2>&1
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
    v_rows NUMBER;
BEGIN
    pkg_customer_hist.load_customer_dim(
        p_load_date  => TO_DATE('${LOAD_DATE}','YYYY-MM-DD'),
        p_source_sys => '${SOURCE_SYS}',
        p_rows_out   => v_rows
    );
    DBMS_OUTPUT.PUT_LINE('Rows processed: ' || v_rows);
END;
/
EXIT SQL.SQLCODE;
EOF

PLSQL_RC=$?

if [ $PLSQL_RC -ne 0 ]; then
    log "ERROR: PL/SQL historization failed (RC=${PLSQL_RC}). Check log: ${LOG_FILE}"
    exit 4
fi

log "PL/SQL historization complete."
log "===== END: ${SCRIPT_NAME} SUCCESS ====="
exit 0
