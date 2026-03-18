CREATE OR REPLACE PACKAGE pkg_dynamic_loader AS
    /*
     * PKG_DYNAMIC_LOADER
     * Uses EXECUTE IMMEDIATE for runtime table/partition routing
     * Complexity: HIGH - Dynamic SQL flagged for manual review
     * Risk: EXECUTE IMMEDIATE prevents static analysis of lineage
     */

    PROCEDURE load_to_partition (
        p_target_table  IN VARCHAR2,
        p_partition_key IN VARCHAR2,
        p_load_date     IN DATE
    );

    PROCEDURE rebuild_indexes (
        p_table_name    IN VARCHAR2
    );

    PROCEDURE truncate_staging (
        p_stage_table   IN VARCHAR2
    );

END pkg_dynamic_loader;
/
