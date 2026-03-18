#!/bin/ksh
# ============================================================
# load_settlement_daily.ksh
# Description : Loads settlement staging and calls PL/SQL fact load
# Called by   : UC4 Job SETTLEMENT_DAILY (JOB_SETTLEMENT_DAILY.xml)
# Arguments   : $1=LOAD_DATE, $2=CURRENCY_CODE, $3=ENV
# Complexity  : MEDIUM - sequential SQL dependencies, error handling
# ============================================================

set -u

LOAD_DATE=$1
CURRENCY_CODE=$2
ENV=$3

LOG_DIR=/opt/datawarehouse/logs
LOG_FILE=${LOG_DIR}/load_settlement_daily_${LOAD_DATE}.log
SCRIPT_DIR=/opt/datawarehouse/sql_scripts
TARGET_TABLE=SETTLEMENT_STG
MAX_RETRIES=3

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${LOG_FILE}
}

if [ "$ENV" = "PROD" ]; then
    ORACLE_CONN="dw_user/dw_pass@DWPROD"
    SOURCE_SYS="CORE_BANKING"
elif [ "$ENV" = "UAT" ]; then
    ORACLE_CONN="dw_user_uat/dw_pass_uat@DWUAT"
    SOURCE_SYS="CORE_BANKING_UAT"
else
    echo "ERROR: Unknown ENV=${ENV}" && exit 1
fi

log "===== START: load_settlement_daily.ksh LOAD_DATE=${LOAD_DATE} CURRENCY=${CURRENCY_CODE} ====="

# ============================================================
# STEP 1: Verify upstream dependencies are complete
# Customer and Policy staging must be done first
# ============================================================
log "Checking upstream dependency: CUST_RAW_STG ..."

CUST_COUNT=$(sqlplus -s ${ORACLE_CONN} << EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT COUNT(*) FROM CUST_RAW_STG WHERE load_date = TO_DATE('${LOAD_DATE}','YYYY-MM-DD') AND rec_status='P';
EXIT;
EOF
)

if [ "${CUST_COUNT:-0}" -eq 0 ]; then
    log "ERROR: CUST_RAW_STG not processed for ${LOAD_DATE}. Run load_customer_daily.ksh first."
    exit 5
fi

log "Dependency check passed: ${CUST_COUNT} customer records found."

# ============================================================
# STEP 2: Load settlement staging
# Calls: sql_scripts/insert_settlement_stage.sql
# Passes: &1=LOAD_DATE, &2=TARGET_TABLE, &3=CURRENCY_CODE
# ============================================================
ATTEMPT=0
STG_RC=1

while [ $ATTEMPT -lt $MAX_RETRIES ] && [ $STG_RC -ne 0 ]; do
    ATTEMPT=$((ATTEMPT + 1))
    log "Attempt ${ATTEMPT}: Calling insert_settlement_stage.sql ..."

    sqlplus -s ${ORACLE_CONN} @${SCRIPT_DIR}/insert_settlement_stage.sql \
        "${LOAD_DATE}" \
        "${TARGET_TABLE}" \
        "${CURRENCY_CODE}" \
        >> ${LOG_FILE} 2>&1

    STG_RC=$?
    if [ $STG_RC -ne 0 ] && [ $ATTEMPT -lt $MAX_RETRIES ]; then
        log "WARNING: Staging failed (RC=${STG_RC}). Retrying in 60s ..."
        sleep 60
    fi
done

if [ $STG_RC -ne 0 ]; then
    log "ERROR: Settlement staging failed after ${MAX_RETRIES} attempts."
    exit 3
fi
log "Settlement staging complete."

# ============================================================
# STEP 3: Call PL/SQL fact load
# ============================================================
log "Calling pkg_settlement_load.load_settlement_fact ..."

sqlplus -s ${ORACLE_CONN} << EOF >> ${LOG_FILE} 2>&1
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
    v_rows     NUMBER;
    v_variance NUMBER;
BEGIN
    pkg_settlement_load.load_settlement_fact(
        p_load_date => TO_DATE('${LOAD_DATE}','YYYY-MM-DD'),
        p_rows_out  => v_rows
    );
    DBMS_OUTPUT.PUT_LINE('Fact rows loaded: ' || v_rows);

    pkg_settlement_load.reconcile_amounts(
        p_load_date => TO_DATE('${LOAD_DATE}','YYYY-MM-DD'),
        p_variance  => v_variance
    );
    IF v_variance <> 0 THEN
        RAISE_APPLICATION_ERROR(-20100, 'Reconciliation failed. Variance=' || v_variance);
    END IF;
END;
/
EXIT SQL.SQLCODE;
EOF

FACT_RC=$?
if [ $FACT_RC -ne 0 ]; then
    log "ERROR: Fact load or reconciliation failed (RC=${FACT_RC})"
    exit 4
fi

log "Settlement fact load and reconciliation complete."
log "===== END: load_settlement_daily.ksh SUCCESS ====="
exit 0
