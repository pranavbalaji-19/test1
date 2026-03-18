-- ============================================================
-- DIMENSION TABLES (SCD Type 2)
-- valid_from / valid_to / is_current pattern
-- ============================================================

CREATE TABLE CUST_DIM (
    cust_sk         NUMBER GENERATED ALWAYS AS IDENTITY,
    customer_id     VARCHAR2(20)    NOT NULL,
    first_name      VARCHAR2(100),
    last_name       VARCHAR2(100),
    date_of_birth   DATE,
    email           VARCHAR2(200),
    phone           VARCHAR2(20),
    address_line1   VARCHAR2(200),
    city            VARCHAR2(100),
    country_code    VARCHAR2(3),
    valid_from      DATE            NOT NULL,
    valid_to        DATE            DEFAULT TO_DATE('9999-12-31','YYYY-MM-DD'),
    is_current      VARCHAR2(1)     DEFAULT 'Y',
    created_by      VARCHAR2(50),
    created_dt      DATE            DEFAULT SYSDATE,
    CONSTRAINT pk_cust_dim PRIMARY KEY (cust_sk)
);

CREATE INDEX idx_cust_dim_id     ON CUST_DIM (customer_id);
CREATE INDEX idx_cust_dim_curr   ON CUST_DIM (customer_id, is_current);

-- ============================================================

CREATE TABLE POLICY_DIM (
    policy_sk       NUMBER GENERATED ALWAYS AS IDENTITY,
    policy_id       VARCHAR2(30)    NOT NULL,
    customer_id     VARCHAR2(20)    NOT NULL,
    product_code    VARCHAR2(20),
    start_date      DATE,
    end_date        DATE,
    premium_amount  NUMBER(15,2),
    currency_code   VARCHAR2(3),
    status          VARCHAR2(20),
    valid_from      DATE            NOT NULL,
    valid_to        DATE            DEFAULT TO_DATE('9999-12-31','YYYY-MM-DD'),
    is_current      VARCHAR2(1)     DEFAULT 'Y',
    created_by      VARCHAR2(50),
    created_dt      DATE            DEFAULT SYSDATE,
    CONSTRAINT pk_policy_dim PRIMARY KEY (policy_sk)
);

CREATE INDEX idx_policy_dim_id   ON POLICY_DIM (policy_id);
CREATE INDEX idx_policy_dim_curr ON POLICY_DIM (policy_id, is_current);
