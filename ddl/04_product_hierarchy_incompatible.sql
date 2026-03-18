-- ============================================================
-- PRODUCT HIERARCHY TABLE
-- Uses Oracle CONNECT BY for hierarchical queries
-- REDESIGN REQUIRED: CONNECT BY is Oracle-proprietary
-- BigQuery does not support CONNECT BY; must be rewritten
-- using recursive CTEs (WITH RECURSIVE)
-- ============================================================

CREATE TABLE PRODUCT_HIERARCHY (
    product_node_id     VARCHAR2(20)    NOT NULL,
    parent_node_id      VARCHAR2(20),
    product_code        VARCHAR2(20),
    product_name        VARCHAR2(200),
    level_no            NUMBER,
    is_leaf             VARCHAR2(1)     DEFAULT 'N',
    effective_date      DATE,
    expiry_date         DATE,
    CONSTRAINT pk_product_hierarchy PRIMARY KEY (product_node_id)
);

-- Example of Oracle-proprietary hierarchical query against this table:
-- SELECT product_node_id,
--        product_name,
--        LEVEL,
--        SYS_CONNECT_BY_PATH(product_name, ' > ') AS full_path
-- FROM   PRODUCT_HIERARCHY
-- START WITH parent_node_id IS NULL
-- CONNECT BY PRIOR product_node_id = parent_node_id
-- ORDER SIBLINGS BY product_name;
--
-- *** INCOMPATIBILITY NOTE ***
-- SYS_CONNECT_BY_PATH, CONNECT_BY_ISLEAF, CONNECT_BY_ROOT are
-- Oracle-specific. BQMS cannot auto-translate. Requires full
-- redesign using BigQuery recursive CTE pattern.
