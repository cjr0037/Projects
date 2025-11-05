-- Setup and Execution Script for POI Table Creation
-- This script provides a step-by-step guide to create the POI table

-- =============================================================================
-- STEP 1: VERIFY DATA AVAILABILITY
-- =============================================================================

-- Check if source tables exist and have data
DO $$
BEGIN
    -- Check overture_places table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'overture_places') THEN
        RAISE NOTICE 'WARNING: Table overture_places does not exist!';
        RAISE NOTICE 'Please ensure Overture Maps places data is loaded into table: overture_places';
    ELSE
        RAISE NOTICE 'Found overture_places table with % rows', (SELECT COUNT(*) FROM overture_places);
    END IF;
    
    -- Check overture_buildings table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'overture_buildings') THEN
        RAISE NOTICE 'WARNING: Table overture_buildings does not exist!';
        RAISE NOTICE 'Please ensure Overture Maps buildings data is loaded into table: overture_buildings';
    ELSE
        RAISE NOTICE 'Found overture_buildings table with % rows', (SELECT COUNT(*) FROM overture_buildings);
    END IF;
END $$;

-- Sample the data structure
SELECT 'PLACES TABLE SAMPLE:' as info;
SELECT id, names, categories, geometry 
FROM overture_places 
LIMIT 3;

SELECT 'BUILDINGS TABLE SAMPLE:' as info;
SELECT id, names, height, geometry 
FROM overture_buildings 
LIMIT 3;

-- =============================================================================
-- STEP 2: CHECK SPATIAL CAPABILITIES
-- =============================================================================

-- Verify PostGIS extension is available
SELECT 'SPATIAL EXTENSION CHECK:' as info;
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') 
        THEN 'PostGIS extension is installed ✓'
        ELSE 'PostGIS extension is NOT installed ✗'
    END as postgis_status;

-- Check spatial reference systems
SELECT 'COORDINATE SYSTEM CHECK:' as info;
SELECT 
    COUNT(DISTINCT ST_SRID(geometry)) as unique_srids,
    STRING_AGG(DISTINCT ST_SRID(geometry)::text, ', ') as srid_list
FROM (
    SELECT geometry FROM overture_places WHERE geometry IS NOT NULL LIMIT 100
    UNION ALL
    SELECT geometry FROM overture_buildings WHERE geometry IS NOT NULL LIMIT 100
) geoms;

-- =============================================================================
-- STEP 3: PERFORMANCE PREPARATION
-- =============================================================================

-- Create spatial indexes if they don't exist
SELECT 'CREATING SPATIAL INDEXES...' as info;

CREATE INDEX IF NOT EXISTS idx_overture_places_geom 
ON overture_places USING GIST(geometry);

CREATE INDEX IF NOT EXISTS idx_overture_buildings_geom 
ON overture_buildings USING GIST(geometry);

-- Create attribute indexes for better performance
CREATE INDEX IF NOT EXISTS idx_overture_places_names 
ON overture_places USING GIN(names) 
WHERE names IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_overture_buildings_names 
ON overture_buildings USING GIN(names) 
WHERE names IS NOT NULL;

-- Update table statistics
ANALYZE overture_places;
ANALYZE overture_buildings;

SELECT 'Indexes created and statistics updated ✓' as info;

-- =============================================================================
-- STEP 4: CONFIGURATION SETTINGS
-- =============================================================================

-- Set work memory for complex queries (adjust based on available RAM)
SET work_mem = '256MB';
SET maintenance_work_mem = '512MB';

-- Enable parallel processing if available
SET max_parallel_workers_per_gather = 4;

SELECT 'Performance settings configured ✓' as info;

-- =============================================================================
-- STEP 5: EXECUTE POI TABLE CREATION
-- =============================================================================

SELECT 'STARTING POI TABLE CREATION...' as info;
SELECT 'Estimated processing time: 5-30 minutes depending on data size' as info;
SELECT 'Start time: ' || CURRENT_TIMESTAMP as info;

-- Drop existing table if it exists
DROP TABLE IF EXISTS poi_table;

-- Execute the main POI creation script
-- Note: This includes the full query from create_poi_table.sql
\i create_poi_table.sql

SELECT 'POI TABLE CREATION COMPLETED ✓' as info;
SELECT 'End time: ' || CURRENT_TIMESTAMP as info;

-- =============================================================================
-- STEP 6: IMMEDIATE VALIDATION
-- =============================================================================

-- Quick validation checks
SELECT 'VALIDATION RESULTS:' as info;

SELECT 
    'Total POI records created: ' || COUNT(*) as result
FROM poi_table;

SELECT 
    'Places with building matches: ' || COUNT(*) || ' (' || 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 1) || '%)' as result
FROM poi_table 
WHERE building_id IS NOT NULL;

SELECT 
    'High confidence matches: ' || COUNT(*) || ' (' || 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table WHERE building_id IS NOT NULL), 1) || '% of matches)' as result
FROM poi_table 
WHERE match_quality IN ('EXACT_NAME_MATCH', 'HIGH_CONFIDENCE');

-- Check for any obvious issues
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'ERROR: No records created ✗'
        WHEN COUNT(*) < (SELECT COUNT(*) FROM overture_places) * 0.9 THEN 'WARNING: Significant data loss detected ⚠'
        ELSE 'Record count looks good ✓'
    END as validation_result
FROM poi_table;

-- =============================================================================
-- STEP 7: NEXT STEPS
-- =============================================================================

SELECT 'SETUP COMPLETE!' as info;
SELECT 'Next steps:' as info;
SELECT '1. Run poi_validation_queries.sql for detailed quality analysis' as step;
SELECT '2. Review match_quality distribution in poi_table' as step;
SELECT '3. Examine high-confidence matches for accuracy' as step;
SELECT '4. Investigate low-confidence matches for potential improvements' as step;
SELECT '5. Consider adjusting parameters and re-running if needed' as step;

-- Quick preview of results
SELECT 'SAMPLE RESULTS:' as info;
SELECT 
    place_id,
    place_name_clean,
    building_name_clean,
    match_quality,
    ROUND(composite_match_score, 3) as match_score,
    ROUND(distance_meters, 1) as distance_m
FROM poi_table 
WHERE building_id IS NOT NULL
ORDER BY composite_match_score DESC
LIMIT 10;