-- ============================================================
-- FACT TABLES
-- Depend on CUST_DIM and POLICY_DIM (downstream in lineage)
-- ============================================================

CREATE TABLE SETTLEMENT_FACT (
    settlement_sk       NUMBER GENERATED ALWAYS AS IDENTITY,
    settlement_id       VARCHAR2(30)    NOT NULL,
    cust_sk             NUMBER          NOT NULL,   -- FK -> CUST_DIM
    policy_sk           NUMBER          NOT NULL,   -- FK -> POLICY_DIM
    settlement_date     DATE            NOT NULL,
    amount              NUMBER(15,2),
    currency_code       VARCHAR2(3),
    settlement_type     VARCHAR2(20),
    reference_no        VARCHAR2(50),
    load_date           DATE,
    CONSTRAINT pk_settlement_fact PRIMARY KEY (settlement_sk),
    CONSTRAINT fk_sf_cust    FOREIGN KEY (cust_sk)   REFERENCES CUST_DIM(cust_sk),
    CONSTRAINT fk_sf_policy  FOREIGN KEY (policy_sk) REFERENCES POLICY_DIM(policy_sk)
);

-- ============================================================
-- ANALYTICAL / REPORTING TABLE
-- Depends on SETTLEMENT_FACT + CUST_DIM + POLICY_DIM
-- Final output of the pipeline chain
-- ============================================================

CREATE TABLE REGULATORY_REPORT_AGG (
    report_sk           NUMBER GENERATED ALWAYS AS IDENTITY,
    report_date         DATE            NOT NULL,
    country_code        VARCHAR2(3),
    product_code        VARCHAR2(20),
    total_settlements   NUMBER(10),
    total_amount        NUMBER(18,2),
    avg_premium         NUMBER(15,2),
    currency_code       VARCHAR2(3),
    generated_dt        DATE            DEFAULT SYSDATE,
    CONSTRAINT pk_reg_report_agg PRIMARY KEY (report_sk)
);

-- ============================================================
-- AUDIT / CONTROL TABLE
-- Tracks job execution history
-- ============================================================

CREATE TABLE JOB_AUDIT_LOG (
    audit_id        NUMBER GENERATED ALWAYS AS IDENTITY,
    job_name        VARCHAR2(100)   NOT NULL,
    script_name     VARCHAR2(200),
    start_time      TIMESTAMP,
    end_time        TIMESTAMP,
    status          VARCHAR2(20),   -- SUCCESS / FAILED / RUNNING
    rows_processed  NUMBER,
    error_msg       VARCHAR2(4000),
    load_date       DATE,
    CONSTRAINT pk_job_audit PRIMARY KEY (audit_id)
);
