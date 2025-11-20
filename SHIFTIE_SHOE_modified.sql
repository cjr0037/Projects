CREATE OR REPLACE PROCEDURE CUSTOMER_DATA.PUBLIC.SHIFTIE_SHOE("SOURCE_DB" VARCHAR(16777216), "SOURCE_SCHEMA" VARCHAR(16777216), "SOURCE_TABLE" VARCHAR(16777216), "TARGET_DB" VARCHAR(16777216), "TARGET_SCHEMA" VARCHAR(16777216), "DEVICE_SAMPLE_SIZE" FLOAT, "ROWS_PER_DEVICE" FLOAT, "FLOWID" VARCHAR(16777216), "CUSTOMERTAG" VARCHAR(16777216))
RETURNS VARCHAR(16777216)
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
    // Generate unique run identifier for filtering //
    const runTimestamp = new Date().toISOString();
    
    // Define static intermediate table name //
    const intermediateTableFull = `CUSTOMER_DATA.SHIFTY.SHIFTED_SIGNALS`;
    
    // Fully qualified source table name //
    const sourceTableFull = `${SOURCE_DB}.${SOURCE_SCHEMA}.${SOURCE_TABLE}`;
    
    // Get the column schema from INFORMATION_SCHEMA, don''t use ListAGG as it won''t preserve the order //
    const getColumnsSQL = `
        SELECT COLUMN_NAME
        FROM ${SOURCE_DB}.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = UPPER(''${SOURCE_SCHEMA}'')
        AND TABLE_NAME = UPPER(''${SOURCE_TABLE}'')
        ORDER BY ORDINAL_POSITION`; 

    let columnList = '''';
    let stmt = snowflake.createStatement({ sqlText: getColumnsSQL });
    let rs = stmt.execute();
    
    // Build column list for SELECT statements //
    let columns = [];
    while (rs.next()) {
        columns.push(rs.getColumnValue(1)); // COLUMN_NAME
    }
    columnList = columns.join('', '');

    // Insert into static intermediate table with shifted signals //
    const insertIntermediateSQL = `
        INSERT INTO ${intermediateTableFull} (
            WITH devices AS (
                SELECT DISTINCT grid
                FROM ${sourceTableFull}
                GROUP BY grid
                HAVING COUNT(*) > ${ROWS_PER_DEVICE}
            ),
            new_aid AS (
                SELECT UUID_STRING() AS genAID
            ),
            deviceSample AS (
                SELECT *,
                    UNIFORM(.001, .003, random()) AS SPATIAL_SHIFT,
                    SIGNALS.PUBLIC.convert_aid_to_grid(new_aid.genAID) AS NEW_GRID,
                    new_aid.genAID AS NEW_ADVERTISERID
                FROM devices
                SAMPLE (${DEVICE_SAMPLE_SIZE} ROWS)
                JOIN new_aid ON 1=1

            ),
            sampled_signals AS (
                SELECT s.*,
                       ROW_NUMBER() OVER (PARTITION BY s.grid ORDER BY RANDOM()) AS rn
                FROM ${sourceTableFull} s
                WHERE grid in (SELECT grid FROM deviceSample)
                QUALIFY rn <= ${ROWS_PER_DEVICE}
            )
            SELECT 
                ${columns.map(col => {
                    switch(col.toUpperCase()) {
                        case ''GRID'':
                            return ''ds.NEW_GRID AS GRID, ss.GRID AS ORIG_GRID'';
                        case ''ADVERTISERID'':
                            return ''ds.NEW_ADVERTISERID AS ADVERTISERID, ss.ADVERTISERID AS ORIG_ADVERTISERID'';
                        case ''LATITUDE'':
                            return ''latitude + ds.SPATIAL_SHIFT AS LATITUDE, LATITUDE AS ORIG_LATITUDE'';
                        case ''LONGITUDE'':
                            return ''longitude + ds.SPATIAL_SHIFT AS LONGITUDE, LONGITUDE AS ORIG_LONGITUDE'';
                        case ''TIMESTAMP'':
                            return ''timestamp + UNIFORM(5000, 10000, RANDOM()) AS TIMESTAMP, TIMESTAMP AS ORIG_TIMESTAMP'';
                        default:
                            return `ss.${col}`;
                    }
                }).filter(col => col !== '''').join('',\\n                '')}
                ,SPATIAL_SHIFT
                ,''${FLOWID}'' AS FLOWID
                ,''${CUSTOMERTAG}'' AS CUSTOMERTAG
                ,''${runTimestamp}''::TIMESTAMP_LTZ AS CREATEDON
            FROM sampled_signals ss
            JOIN deviceSample ds ON ss.GRID = ds.GRID
        )`;
    
    // Insert back to source table - filtered by this run''s records only
    const insertBackToSourceSQL = `
            INSERT INTO ${sourceTableFull} 
            SELECT * EXCLUDE(ORIG_GRID, ORIG_ADVERTISERID, ORIG_LATITUDE, ORIG_LONGITUDE, ORIG_TIMESTAMP, SPATIAL_SHIFT, FLOWID, CUSTOMERTAG, CREATEDON) 
            FROM ${intermediateTableFull}
            WHERE FLOWID = ''${FLOWID}''
              AND CUSTOMERTAG = ''${CUSTOMERTAG}''
              AND CREATEDON = ''${runTimestamp}''::TIMESTAMP_LTZ
        `;
    
    try {
        // Execute the SQL statements
        snowflake.execute({ sqlText: insertIntermediateSQL });
        snowflake.execute({ sqlText: insertBackToSourceSQL });
        
        return `Success! Inserted shifted signals into:\\n1. Intermediate: ${intermediateTableFull}\\n2. Source: ${sourceTableFull}\\nFilter: FLOWID=''${FLOWID}'', CUSTOMERTAG=''${CUSTOMERTAG}'', CREATEDON=''${runTimestamp}''`;
    } catch (err) {
        return `Error: ${err.message}`;
    }
';
