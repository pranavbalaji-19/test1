#!/bin/ksh
# ============================================================
# load_policy_daily.ksh
# Description : Loads policy data into staging then calls
#               PL/SQL to load POLICY_DIM (SCD Type 2)
# Called by   : UC4 Job POLICY_DAILY_LOAD (JOB_POLICY_DAILY.xml)
# Arguments   : $1=LOAD_DATE, $2=SOURCE_SYSTEM, $3=PRODUCT_CODE, $4=ENV
# Complexity  : MEDIUM - conditional branching, error codes, SQL call
# ============================================================

set -u

LOAD_DATE=$1
SOURCE_SYS=$2
PRODUCT_CODE=$3
ENV=$4

LOG_DIR=/opt/datawarehouse/logs
LOG_FILE=${LOG_DIR}/load_policy_daily_${LOAD_DATE}.log
SCRIPT_DIR=/opt/datawarehouse/sql_scripts

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${LOG_FILE}
}

# --- Determine Oracle connection based on ENV and PRODUCT ---
if [ "$ENV" = "PROD" ]; then
    ORACLE_CONN="dw_user/dw_pass@DWPROD"
    log "Running in PRODUCTION mode."
elif [ "$ENV" = "UAT" ]; then
    ORACLE_CONN="dw_user_uat/dw_pass_uat@DWUAT"
    log "Running in UAT mode."
else
    log "ERROR: Invalid ENV=${ENV}"
    exit 1
fi

# --- Product-specific branching ---
if [ "$PRODUCT_CODE" = "ALL" ]; then
    log "Full product load selected."
    FILTER_PARAM="ALL"
elif [ "$PRODUCT_CODE" = "LIFE" ] || [ "$PRODUCT_CODE" = "ANNUITY" ]; then
    log "Partial product load: ${PRODUCT_CODE}"
    FILTER_PARAM="${PRODUCT_CODE}"
else
    log "WARNING: Unknown PRODUCT_CODE=${PRODUCT_CODE}. Defaulting to ALL."
    FILTER_PARAM="ALL"
fi

log "===== START: load_policy_daily.ksh LOAD_DATE=${LOAD_DATE} PRODUCT=${FILTER_PARAM} ====="

# ============================================================
# STEP 1: Policy staging load
# Calls: sql_scripts/insert_policy_stage.sql
# Passes: &1=LOAD_DATE, &2=SOURCE_SYS, &3=FILTER_PARAM
# ============================================================
log "Loading POLICY_RAW_STG ..."

sqlplus -s ${ORACLE_CONN} @${SCRIPT_DIR}/insert_policy_stage.sql \
    "${LOAD_DATE}" \
    "${SOURCE_SYS}" \
    "${FILTER_PARAM}" \
    >> ${LOG_FILE} 2>&1

STG_RC=$?
if [ $STG_RC -ne 0 ]; then
    log "ERROR: insert_policy_stage.sql failed (RC=${STG_RC})"
    exit 2
fi
log "Policy staging complete."

# ============================================================
# STEP 2: Call PL/SQL for SCD Type 2 Policy dimension load
# Note: pkg_policy_hist reuses the same SCD2 pattern as
#       pkg_customer_hist (same architecture, different table)
# ============================================================
log "Calling pkg_policy_hist.load_policy_dim ..."

sqlplus -s ${ORACLE_CONN} << EOF >> ${LOG_FILE} 2>&1
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
    v_rows NUMBER;
BEGIN
    pkg_policy_hist.load_policy_dim(
        p_load_date   => TO_DATE('${LOAD_DATE}','YYYY-MM-DD'),
        p_source_sys  => '${SOURCE_SYS}',
        p_product_cd  => '${FILTER_PARAM}',
        p_rows_out    => v_rows
    );
    DBMS_OUTPUT.PUT_LINE('Policy dim rows processed: ' || v_rows);
END;
/
EXIT SQL.SQLCODE;
EOF

PKG_RC=$?
if [ $PKG_RC -ne 0 ]; then
    log "ERROR: pkg_policy_hist.load_policy_dim failed (RC=${PKG_RC})"
    exit 3
fi

log "Policy dimension load complete."
log "===== END: load_policy_daily.ksh SUCCESS ====="
exit 0
