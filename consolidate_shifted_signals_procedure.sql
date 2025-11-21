CREATE OR REPLACE PROCEDURE CUSTOMER_DATA.SHIFTY.CONSOLIDATE_SHIFTED_SIGNALS()
RETURNS VARCHAR(16777216)
LANGUAGE JAVASCRIPT
EXECUTE AS OWNER
AS
$$
    // Define the target table schema with all expected columns and their data types
    var target_columns = [
        {name: 'GRID', type: 'VARCHAR(16777216)'},
        {name: 'ORIG_GRID', type: 'VARCHAR(16777216)'},
        {name: 'ADVERTISERID', type: 'VARCHAR(36)'},
        {name: 'ORIG_ADVERTISERID', type: 'VARCHAR(16777216)'},
        {name: 'LATITUDE', type: 'FLOAT'},
        {name: 'ORIG_LATITUDE', type: 'FLOAT'},
        {name: 'LONGITUDE', type: 'FLOAT'},
        {name: 'ORIG_LONGITUDE', type: 'FLOAT'},
        {name: 'TIMESTAMP', type: 'NUMBER(38,0)'},
        {name: 'ORIG_TIMESTAMP', type: 'NUMBER(38,0)'},
        {name: 'TIMEZONE', type: 'VARCHAR(16777216)'},
        {name: 'IPADDRESS', type: 'VARCHAR(16777216)'},
        {name: 'FORENSICFLAG', type: 'NUMBER(38,0)'},
        {name: 'DEVICETYPE', type: 'VARCHAR(16777216)'},
        {name: 'RECORDCOUNT', type: 'NUMBER(38,0)'},
        {name: 'COUNTRYCODE', type: 'VARCHAR(16777216)'},
        {name: 'SPATIAL_SHIFT', type: 'NUMBER(5,3)'},
        {name: 'FLOWDEF_ID', type: 'VARCHAR(54)'},
        {name: 'CUSTOMERTAG', type: 'VARCHAR(6)'},
        {name: 'CREATEDON', type: 'TIMESTAMP_LTZ(9)'}
    ];
    
    var database = 'CUSTOMER_DATA';
    var schema = 'SHIFTY';
    var table_prefix = 'SHIFTED_SIGNALS_RQOBS';
    var consolidated_table = 'SHIFTED_SIGNALS';
    
    // ========================================================================
    // SECTION 1: Discover all tables with the specified prefix
    // ========================================================================
    var get_tables_query = `
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = '${schema}'
        AND TABLE_CATALOG = '${database}'
        AND TABLE_TYPE = 'BASE TABLE'
        AND TABLE_NAME LIKE '${table_prefix}%'
        AND TABLE_NAME != '${consolidated_table}'
        ORDER BY TABLE_NAME
    `;
    
    var tables_result = snowflake.execute({ sqlText: get_tables_query });
    var source_tables = [];
    
    while (tables_result.next()) {
        source_tables.push(tables_result.getColumnValue(1));
    }
    
    // If no source tables found, return early
    if (source_tables.length === 0) {
        return `No tables found with prefix '${table_prefix}' in ${database}.${schema}. Nothing to consolidate.`;
    }
    
    // ========================================================================
    // SECTION 2: For each source table, get its columns and build SELECT
    // ========================================================================
    var union_queries = [];
    
    for (var i = 0; i < source_tables.length; i++) {
        var table_name = source_tables[i];
        
        // Query to get all columns in the current table
        var get_columns_query = `
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = '${schema}'
            AND TABLE_CATALOG = '${database}'
            AND TABLE_NAME = '${table_name}'
        `;
        
        var columns_result = snowflake.execute({ sqlText: get_columns_query });
        var existing_columns = {};
        
        // Store existing columns in a lookup object
        while (columns_result.next()) {
            existing_columns[columns_result.getColumnValue(1)] = true;
        }
        
        // Build SELECT statement with NULL for missing columns
        var select_parts = [];
        for (var j = 0; j < target_columns.length; j++) {
            var col = target_columns[j];
            
            // Handle column name mapping: FLOWID in source -> FLOWDEF_ID in target
            if (col.name === 'FLOWDEF_ID') {
                if (existing_columns['FLOWID']) {
                    // Source table has FLOWID, map it to FLOWDEF_ID
                    select_parts.push('FLOWID AS FLOWDEF_ID');
                } else if (existing_columns['FLOWDEF_ID']) {
                    // Source table already has FLOWDEF_ID
                    select_parts.push('FLOWDEF_ID');
                } else {
                    // Column missing, use NULL
                    select_parts.push(`NULL::${col.type} AS FLOWDEF_ID`);
                }
            } else if (existing_columns[col.name]) {
                // Column exists, select it
                select_parts.push(col.name);
            } else {
                // Column missing, use NULL with appropriate cast
                select_parts.push(`NULL::${col.type} AS ${col.name}`);
            }
        }
        
        var select_query = `SELECT ${select_parts.join(', ')} FROM ${database}.${schema}.${table_name}`;
        union_queries.push(select_query);
    }
    
    // ========================================================================
    // SECTION 3: Insert into the consolidated table using UNION ALL
    // ========================================================================
    var insert_query = `INSERT INTO ${database}.${schema}.${consolidated_table}\n`;
    insert_query += union_queries.join('\nUNION ALL\n');
    
    try {
        snowflake.execute({ sqlText: insert_query });
    } catch (err) {
        return `Error inserting into consolidated table: ${err.message}`;
    }
    
    // ========================================================================
    // SECTION 4: Get row count from consolidated table
    // ========================================================================
    var count_query = `SELECT COUNT(*) FROM ${database}.${schema}.${consolidated_table}`;
    var count_result = snowflake.execute({ sqlText: count_query });
    count_result.next();
    var total_rows = count_result.getColumnValue(1);
    
    // ========================================================================
    // SECTION 5: Drop source tables after successful consolidation
    // ========================================================================
    var dropped_tables = [];
    var failed_drops = [];
    
    for (var k = 0; k < source_tables.length; k++) {
        var table_to_drop = source_tables[k];
        var drop_query = `DROP TABLE IF EXISTS ${database}.${schema}.${table_to_drop}`;
        
        try {
            snowflake.execute({ sqlText: drop_query });
            dropped_tables.push(table_to_drop);
        } catch (err) {
            failed_drops.push(`${table_to_drop}: ${err.message}`);
        }
    }
    
    // ========================================================================
    // SECTION 6: Build and return summary message
    // ========================================================================
    var summary = `Successfully inserted data from ${source_tables.length} table(s) into ${consolidated_table}\n`;
    summary += `Total rows in consolidated table: ${total_rows}\n`;
    summary += `Source tables dropped: ${dropped_tables.length}\n`;
    
    if (failed_drops.length > 0) {
        summary += `\nWARNING: Failed to drop ${failed_drops.length} table(s):\n`;
        summary += failed_drops.join('\n');
    }
    
    return summary;
$$;

-- ==============================================================================
-- USAGE EXAMPLE:
-- ==============================================================================
-- To execute the procedure, run:
-- CALL CUSTOMER_DATA.SHIFTY.CONSOLIDATE_SHIFTED_SIGNALS();
