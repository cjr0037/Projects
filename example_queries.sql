-- ============================================================================
-- Example Queries and Testing for POI Table Creation
-- ============================================================================
-- Use these queries to verify your setup and test the matching logic
-- ============================================================================

-- ============================================================================
-- PART 1: Pre-flight Checks
-- ============================================================================

-- 1. Verify places table exists and has data
SELECT 
    COUNT(*) AS total_places,
    COUNT(DISTINCT id) AS unique_places,
    COUNT(geometry) AS places_with_geometry,
    COUNT(names) AS places_with_names
FROM overture_maps_places;

-- 2. Verify buildings table exists and has data
SELECT 
    COUNT(*) AS total_buildings,
    COUNT(DISTINCT id) AS unique_buildings,
    COUNT(geometry) AS buildings_with_geometry,
    COUNT(names) AS buildings_with_names
FROM overture_maps_buildings;

-- 3. Check geometry types
SELECT 
    ST_GEOMETRYTYPE(geometry) AS geom_type,
    COUNT(*) AS count
FROM overture_maps_places
GROUP BY geom_type;

SELECT 
    ST_GEOMETRYTYPE(geometry) AS geom_type,
    COUNT(*) AS count
FROM overture_maps_buildings
GROUP BY geom_type;

-- 4. Examine names structure (important for name extraction)
SELECT 
    id,
    names,
    names:primary::STRING AS primary_name,
    names:common[0].value::STRING AS common_name_0,
    names:common::ARRAY AS all_common_names
FROM overture_maps_places
LIMIT 10;

SELECT 
    id,
    names,
    names:primary::STRING AS primary_name
FROM overture_maps_buildings
WHERE names IS NOT NULL
LIMIT 10;

-- 5. Check spatial distribution (sample bounding box)
SELECT 
    ST_XMIN(ST_ENVELOPE_AGG(geometry)) AS min_longitude,
    ST_XMAX(ST_ENVELOPE_AGG(geometry)) AS max_longitude,
    ST_YMIN(ST_ENVELOPE_AGG(geometry)) AS min_latitude,
    ST_YMAX(ST_ENVELOPE_AGG(geometry)) AS max_latitude
FROM overture_maps_places;

-- ============================================================================
-- PART 2: Test on Small Sample
-- ============================================================================

-- Test the matching logic on a small sample (faster for development)
CREATE OR REPLACE TEMPORARY TABLE sample_places AS
SELECT * FROM overture_maps_places LIMIT 1000;

CREATE OR REPLACE TEMPORARY TABLE sample_buildings AS
SELECT b.* 
FROM overture_maps_buildings b
INNER JOIN sample_places p
    ON ST_DWITHIN(p.geometry, b.geometry, 100)
;

-- Now test with samples (replace table names in main script temporarily)
SELECT 
    p.id AS place_id,
    p.names:primary::STRING AS place_name,
    b.id AS building_id,
    b.names:primary::STRING AS building_name,
    ST_CONTAINS(b.geometry, p.geometry) AS contained,
    ST_DISTANCE(p.geometry, b.geometry) AS distance,
    JAROWINKLER_SIMILARITY(
        UPPER(COALESCE(p.names:primary::STRING, '')),
        UPPER(COALESCE(b.names:primary::STRING, ''))
    ) AS name_similarity
FROM sample_places p
CROSS JOIN sample_buildings b
WHERE ST_DWITHIN(p.geometry, b.geometry, 50)
LIMIT 100;

-- ============================================================================
-- PART 3: Analyze Results After Running Main Script
-- ============================================================================

-- Basic statistics
SELECT 
    COUNT(*) AS total_pois,
    COUNT(building_id) AS matched_pois,
    COUNT(*) - COUNT(building_id) AS unmatched_pois,
    ROUND(100.0 * COUNT(building_id) / COUNT(*), 2) AS match_rate_pct
FROM poi_table;

-- Distribution of match quality
SELECT 
    CASE 
        WHEN building_id IS NULL THEN '0. No Match'
        WHEN composite_score >= 95 THEN '1. Excellent (95+)'
        WHEN composite_score >= 85 THEN '2. Very Good (85-94)'
        WHEN composite_score >= 75 THEN '3. Good (75-84)'
        WHEN composite_score >= 60 THEN '4. Fair (60-74)'
        WHEN composite_score >= 40 THEN '5. Poor (40-59)'
        ELSE '6. Very Poor (<40)'
    END AS quality_tier,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM poi_table
GROUP BY quality_tier
ORDER BY quality_tier;

-- Top matches by score
SELECT 
    place_name,
    building_name,
    is_contained,
    ROUND(distance_meters, 2) AS dist_m,
    ROUND(name_similarity_score, 1) AS name_sim,
    ROUND(composite_score, 1) AS score
FROM poi_table
WHERE building_id IS NOT NULL
ORDER BY composite_score DESC
LIMIT 50;

-- Problematic matches (for review)
SELECT 
    place_name,
    building_name,
    is_contained,
    ROUND(distance_meters, 2) AS dist_m,
    ROUND(name_similarity_score, 1) AS name_sim,
    ROUND(composite_score, 1) AS score
FROM poi_table
WHERE building_id IS NOT NULL
  AND composite_score < 60
ORDER BY composite_score ASC
LIMIT 50;

-- Places with very different names but spatial match
SELECT 
    place_name,
    building_name,
    is_contained,
    ROUND(distance_meters, 2) AS dist_m,
    ROUND(name_similarity_score, 1) AS name_sim,
    ROUND(composite_score, 1) AS score
FROM poi_table
WHERE building_id IS NOT NULL
  AND distance_meters < 10
  AND name_similarity_score < 50
LIMIT 50;

-- ============================================================================
-- PART 4: Category Analysis
-- ============================================================================

-- Match rate by place category
SELECT 
    categories:primary::STRING AS category,
    COUNT(*) AS total,
    COUNT(building_id) AS matched,
    ROUND(100.0 * COUNT(building_id) / COUNT(*), 1) AS match_pct,
    ROUND(AVG(CASE WHEN building_id IS NOT NULL THEN composite_score END), 1) AS avg_score
FROM poi_table
GROUP BY category
HAVING COUNT(*) >= 10
ORDER BY total DESC
LIMIT 30;

-- ============================================================================
-- PART 5: Spatial Analysis
-- ============================================================================

-- Distance distribution for matched POIs
SELECT 
    CASE 
        WHEN distance_meters = 0 THEN '0m (Boundary)'
        WHEN distance_meters <= 5 THEN '0-5m'
        WHEN distance_meters <= 10 THEN '5-10m'
        WHEN distance_meters <= 20 THEN '10-20m'
        WHEN distance_meters <= 30 THEN '20-30m'
        WHEN distance_meters <= 50 THEN '30-50m'
        ELSE '>50m'
    END AS distance_range,
    COUNT(*) AS count,
    ROUND(AVG(composite_score), 1) AS avg_score,
    ROUND(AVG(name_similarity_score), 1) AS avg_name_sim
FROM poi_table
WHERE building_id IS NOT NULL
GROUP BY distance_range
ORDER BY 
    CASE distance_range
        WHEN '0m (Boundary)' THEN 1
        WHEN '0-5m' THEN 2
        WHEN '5-10m' THEN 3
        WHEN '10-20m' THEN 4
        WHEN '20-30m' THEN 5
        WHEN '30-50m' THEN 6
        ELSE 7
    END;

-- Containment analysis
SELECT 
    is_contained,
    COUNT(*) AS count,
    ROUND(AVG(distance_meters), 2) AS avg_distance,
    ROUND(AVG(name_similarity_score), 1) AS avg_name_sim,
    ROUND(AVG(composite_score), 1) AS avg_composite_score
FROM poi_table
WHERE building_id IS NOT NULL
GROUP BY is_contained;

-- ============================================================================
-- PART 6: Data Quality Checks
-- ============================================================================

-- Check for duplicate place_ids (should be 0)
SELECT 
    'Duplicate place_ids' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT place_id, COUNT(*) AS cnt
    FROM poi_table
    GROUP BY place_id
    HAVING cnt > 1
);

-- Check for NULL geometries
SELECT 
    'NULL place geometries' AS check_name,
    COUNT(*) AS issue_count
FROM poi_table
WHERE place_geometry IS NULL

UNION ALL

SELECT 
    'NULL building geometries (where matched)' AS check_name,
    COUNT(*) AS issue_count
FROM poi_table
WHERE building_id IS NOT NULL 
  AND building_geometry IS NULL;

-- Check for unrealistic distances (possible data issues)
SELECT 
    place_id,
    place_name,
    building_name,
    distance_meters,
    is_contained
FROM poi_table
WHERE building_id IS NOT NULL
  AND distance_meters > 100  -- Should not happen with 50m threshold
LIMIT 20;

-- ============================================================================
-- PART 7: Export Examples
-- ============================================================================

-- Export high-quality matches as GeoJSON
SELECT 
    OBJECT_CONSTRUCT(
        'type', 'Feature',
        'properties', OBJECT_CONSTRUCT(
            'place_id', place_id,
            'place_name', place_name,
            'building_id', building_id,
            'building_name', building_name,
            'composite_score', composite_score,
            'match_quality', 
                CASE 
                    WHEN composite_score >= 90 THEN 'excellent'
                    WHEN composite_score >= 75 THEN 'good'
                    ELSE 'fair'
                END
        ),
        'geometry', PARSE_JSON(ST_ASGEOJSON(place_geometry))
    ) AS geojson_feature
FROM poi_table
WHERE building_id IS NOT NULL
  AND composite_score >= 75
LIMIT 1000;

-- Export building polygons with matched POIs
SELECT 
    building_id,
    building_name,
    COUNT(*) AS num_pois_in_building,
    ARRAY_AGG(place_name) AS place_names,
    ST_ASGEOJSON(ANY_VALUE(building_geometry)) AS building_geojson
FROM poi_table
WHERE building_id IS NOT NULL
  AND is_contained = TRUE
GROUP BY building_id, building_name
HAVING COUNT(*) >= 2  -- Buildings with multiple POIs
ORDER BY num_pois_in_building DESC
LIMIT 100;

-- ============================================================================
-- PART 8: Performance Testing
-- ============================================================================

-- Check table sizes
SELECT 
    'poi_table' AS table_name,
    COUNT(*) AS row_count,
    SUM(LENGTH(TO_JSON(OBJECT_CONSTRUCT(*)))) AS approx_size_bytes
FROM poi_table

UNION ALL

SELECT 
    'overture_maps_places' AS table_name,
    COUNT(*) AS row_count,
    SUM(LENGTH(TO_JSON(OBJECT_CONSTRUCT(*)))) AS approx_size_bytes
FROM overture_maps_places

UNION ALL

SELECT 
    'overture_maps_buildings' AS table_name,
    COUNT(*) AS row_count,
    SUM(LENGTH(TO_JSON(OBJECT_CONSTRUCT(*)))) AS approx_size_bytes
FROM overture_maps_buildings;

-- Check query performance (add EXPLAIN if needed)
SELECT 
    place_name,
    building_name,
    composite_score
FROM poi_table
WHERE ST_DWITHIN(place_geometry, ST_MAKEPOINT(-122.4194, 37.7749), 1000)
  AND composite_score >= 80
ORDER BY composite_score DESC
LIMIT 100;
