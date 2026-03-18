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
