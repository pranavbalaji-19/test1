-- ============================================================
-- STAGING TABLES
-- Used as landing zone before transformation
-- ============================================================

CREATE TABLE CUST_RAW_STG (
    stg_id          NUMBER GENERATED ALWAYS AS IDENTITY,
    customer_id     VARCHAR2(20)    NOT NULL,
    first_name      VARCHAR2(100),
    last_name       VARCHAR2(100),
    date_of_birth   DATE,
    email           VARCHAR2(200),
    phone           VARCHAR2(20),
    address_line1   VARCHAR2(200),
    city            VARCHAR2(100),
    country_code    VARCHAR2(3),
    load_date       DATE            NOT NULL,
    source_system   VARCHAR2(50),
    rec_status      VARCHAR2(1)     DEFAULT 'N',
    CONSTRAINT pk_cust_raw_stg PRIMARY KEY (stg_id)
);

CREATE TABLE POLICY_RAW_STG (
    stg_id          NUMBER GENERATED ALWAYS AS IDENTITY,
    policy_id       VARCHAR2(30)    NOT NULL,
    customer_id     VARCHAR2(20)    NOT NULL,
    product_code    VARCHAR2(20),
    start_date      DATE,
    end_date        DATE,
    premium_amount  NUMBER(15,2),
    currency_code   VARCHAR2(3),
    status          VARCHAR2(20),
    load_date       DATE            NOT NULL,
    source_system   VARCHAR2(50),
    rec_status      VARCHAR2(1)     DEFAULT 'N',
    CONSTRAINT pk_policy_raw_stg PRIMARY KEY (stg_id)
);

CREATE TABLE SETTLEMENT_STG (
    stg_id              NUMBER GENERATED ALWAYS AS IDENTITY,
    settlement_id       VARCHAR2(30)    NOT NULL,
    policy_id           VARCHAR2(30)    NOT NULL,
    settlement_date     DATE            NOT NULL,
    amount              NUMBER(15,2),
    currency_code       VARCHAR2(3),
    settlement_type     VARCHAR2(20),
    reference_no        VARCHAR2(50),
    load_date           DATE            NOT NULL,
    CONSTRAINT pk_settlement_stg PRIMARY KEY (stg_id)
);
