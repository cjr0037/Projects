-- POI Table Validation and Quality Assessment Queries
-- Run these queries after creating the POI table to validate results and assess quality

-- =============================================================================
-- 1. BASIC STATISTICS AND OVERVIEW
-- =============================================================================

-- Overall matching statistics
SELECT 
    'Total Places' as metric,
    COUNT(*) as count,
    ROUND(100.0, 2) as percentage
FROM poi_table

UNION ALL

SELECT 
    'Places with Building Matches' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 2) as percentage
FROM poi_table 
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'Places without Building Matches' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 2) as percentage
FROM poi_table 
WHERE building_id IS NULL;

-- Match quality distribution
SELECT 
    match_quality,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(composite_match_score), 3) as avg_match_score,
    ROUND(MIN(composite_match_score), 3) as min_match_score,
    ROUND(MAX(composite_match_score), 3) as max_match_score,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters
FROM poi_table 
GROUP BY match_quality
ORDER BY 
    CASE match_quality
        WHEN 'EXACT_NAME_MATCH' THEN 1
        WHEN 'HIGH_CONFIDENCE' THEN 2
        WHEN 'MEDIUM_CONFIDENCE' THEN 3
        WHEN 'LOW_CONFIDENCE' THEN 4
        WHEN 'VERY_LOW_CONFIDENCE' THEN 5
        WHEN 'NO_BUILDING_MATCH' THEN 6
    END;

-- Spatial relationship distribution
SELECT 
    spatial_relationship,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters,
    ROUND(AVG(composite_match_score), 3) as avg_match_score
FROM poi_table 
GROUP BY spatial_relationship
ORDER BY count DESC;

-- =============================================================================
-- 2. DATA QUALITY CHECKS
-- =============================================================================

-- Check for potential duplicate building assignments
SELECT 
    'Buildings matched to multiple places' as check_type,
    COUNT(*) as issue_count
FROM (
    SELECT building_id, COUNT(*) as match_count
    FROM poi_table 
    WHERE building_id IS NOT NULL
    GROUP BY building_id 
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

-- Check for places with suspiciously high distances
SELECT 
    'Places with distance > 200m' as check_type,
    COUNT(*) as issue_count
FROM poi_table 
WHERE distance_meters > 200

UNION ALL

-- Check for matches with very low confidence but high distance
SELECT 
    'Low confidence matches with high distance' as check_type,
    COUNT(*) as issue_count
FROM poi_table 
WHERE match_quality IN ('LOW_CONFIDENCE', 'VERY_LOW_CONFIDENCE')
  AND distance_meters > 100

UNION ALL

-- Check for exact name matches with high distance (potential coordinate issues)
SELECT 
    'Exact name matches with distance > 50m' as check_type,
    COUNT(*) as issue_count
FROM poi_table 
WHERE match_quality = 'EXACT_NAME_MATCH'
  AND distance_meters > 50;

-- =============================================================================
-- 3. DETAILED QUALITY ANALYSIS
-- =============================================================================

-- Top 20 best matches for manual review
SELECT 
    place_id,
    building_id,
    place_name_clean,
    building_name_clean,
    match_quality,
    ROUND(composite_match_score, 3) as match_score,
    ROUND(name_similarity_score, 3) as name_score,
    ROUND(distance_meters, 2) as distance_m,
    ROUND(building_area_sqm, 0) as building_area_sqm,
    spatial_relationship
FROM poi_table 
WHERE building_id IS NOT NULL
ORDER BY composite_match_score DESC, distance_meters ASC
LIMIT 20;

-- Top 20 worst matches for manual review
SELECT 
    place_id,
    building_id,
    place_name_clean,
    building_name_clean,
    match_quality,
    ROUND(composite_match_score, 3) as match_score,
    ROUND(name_similarity_score, 3) as name_score,
    ROUND(distance_meters, 2) as distance_m,
    spatial_relationship
FROM poi_table 
WHERE building_id IS NOT NULL
  AND match_quality NOT IN ('NO_BUILDING_MATCH')
ORDER BY composite_match_score ASC, distance_meters DESC
LIMIT 20;

-- Places without matches - sample for investigation
SELECT 
    place_id,
    place_name_clean,
    place_categories,
    ST_X(place_geometry) as longitude,
    ST_Y(place_geometry) as latitude
FROM poi_table 
WHERE building_id IS NULL
ORDER BY place_id
LIMIT 20;

-- =============================================================================
-- 4. DISTANCE AND PROXIMITY ANALYSIS
-- =============================================================================

-- Distance distribution for matched places
SELECT 
    CASE 
        WHEN distance_meters <= 5 THEN '0-5m (Inside/Adjacent)'
        WHEN distance_meters <= 10 THEN '5-10m (Very Close)'
        WHEN distance_meters <= 25 THEN '10-25m (Close)'
        WHEN distance_meters <= 50 THEN '25-50m (Nearby)'
        WHEN distance_meters <= 100 THEN '50-100m (Distant)'
        ELSE '>100m (Very Distant)'
    END as distance_range,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(composite_match_score), 3) as avg_match_score
FROM poi_table 
WHERE building_id IS NOT NULL
GROUP BY 
    CASE 
        WHEN distance_meters <= 5 THEN '0-5m (Inside/Adjacent)'
        WHEN distance_meters <= 10 THEN '5-10m (Very Close)'
        WHEN distance_meters <= 25 THEN '10-25m (Close)'
        WHEN distance_meters <= 50 THEN '25-50m (Nearby)'
        WHEN distance_meters <= 100 THEN '50-100m (Distant)'
        ELSE '>100m (Very Distant)'
    END
ORDER BY MIN(distance_meters);

-- Building size vs match quality
SELECT 
    CASE 
        WHEN building_area_sqm <= 100 THEN 'Small (<100 sqm)'
        WHEN building_area_sqm <= 500 THEN 'Medium (100-500 sqm)'
        WHEN building_area_sqm <= 2000 THEN 'Large (500-2000 sqm)'
        ELSE 'Very Large (>2000 sqm)'
    END as building_size,
    COUNT(*) as count,
    ROUND(AVG(composite_match_score), 3) as avg_match_score,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters
FROM poi_table 
WHERE building_id IS NOT NULL AND building_area_sqm IS NOT NULL
GROUP BY 
    CASE 
        WHEN building_area_sqm <= 100 THEN 'Small (<100 sqm)'
        WHEN building_area_sqm <= 500 THEN 'Medium (100-500 sqm)'
        WHEN building_area_sqm <= 2000 THEN 'Large (500-2000 sqm)'
        ELSE 'Very Large (>2000 sqm)'
    END
ORDER BY MIN(building_area_sqm);

-- =============================================================================
-- 5. NAME MATCHING ANALYSIS
-- =============================================================================

-- Exact matches analysis
SELECT 
    'Exact Name Matches' as match_type,
    COUNT(*) as count,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters,
    ROUND(MIN(distance_meters), 2) as min_distance_meters,
    ROUND(MAX(distance_meters), 2) as max_distance_meters
FROM poi_table 
WHERE exact_match_score = 1.0

UNION ALL

-- Substring matches analysis
SELECT 
    'Substring Matches' as match_type,
    COUNT(*) as count,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters,
    ROUND(MIN(distance_meters), 2) as min_distance_meters,
    ROUND(MAX(distance_meters), 2) as max_distance_meters
FROM poi_table 
WHERE substring_score > 0 AND exact_match_score = 0

UNION ALL

-- Word overlap matches analysis
SELECT 
    'Word Overlap Matches' as match_type,
    COUNT(*) as count,
    ROUND(AVG(distance_meters), 2) as avg_distance_meters,
    ROUND(MIN(distance_meters), 2) as min_distance_meters,
    ROUND(MAX(distance_meters), 2) as max_distance_meters
FROM poi_table 
WHERE word_overlap_score > 0 AND substring_score = 0 AND exact_match_score = 0;

-- Name length analysis
SELECT 
    CASE 
        WHEN LENGTH(place_name_clean) <= 10 THEN 'Short (≤10 chars)'
        WHEN LENGTH(place_name_clean) <= 20 THEN 'Medium (11-20 chars)'
        WHEN LENGTH(place_name_clean) <= 30 THEN 'Long (21-30 chars)'
        ELSE 'Very Long (>30 chars)'
    END as name_length_category,
    COUNT(*) as count,
    ROUND(AVG(name_similarity_score), 3) as avg_name_similarity,
    ROUND(AVG(composite_match_score), 3) as avg_composite_score
FROM poi_table 
WHERE building_id IS NOT NULL
GROUP BY 
    CASE 
        WHEN LENGTH(place_name_clean) <= 10 THEN 'Short (≤10 chars)'
        WHEN LENGTH(place_name_clean) <= 20 THEN 'Medium (11-20 chars)'
        WHEN LENGTH(place_name_clean) <= 30 THEN 'Long (21-30 chars)'
        ELSE 'Very Long (>30 chars)'
    END
ORDER BY MIN(LENGTH(place_name_clean));

-- =============================================================================
-- 6. CATEGORY-BASED ANALYSIS
-- =============================================================================

-- Match success rate by place category (if categories are available)
SELECT 
    COALESCE(
        JSON_EXTRACT_SCALAR(place_categories, '$[0]'),
        'Unknown'
    ) as primary_category,
    COUNT(*) as total_places,
    COUNT(building_id) as matched_places,
    ROUND(COUNT(building_id) * 100.0 / COUNT(*), 2) as match_rate_percent,
    ROUND(AVG(CASE WHEN building_id IS NOT NULL THEN composite_match_score END), 3) as avg_match_score
FROM poi_table 
GROUP BY 
    COALESCE(
        JSON_EXTRACT_SCALAR(place_categories, '$[0]'),
        'Unknown'
    )
HAVING COUNT(*) >= 10  -- Only show categories with at least 10 places
ORDER BY match_rate_percent DESC, total_places DESC
LIMIT 20;

-- =============================================================================
-- 7. GEOGRAPHIC DISTRIBUTION ANALYSIS
-- =============================================================================

-- Geographic bounds of matched vs unmatched places
SELECT 
    'Matched Places' as place_type,
    COUNT(*) as count,
    ROUND(MIN(ST_X(place_geometry)), 6) as min_longitude,
    ROUND(MAX(ST_X(place_geometry)), 6) as max_longitude,
    ROUND(MIN(ST_Y(place_geometry)), 6) as min_latitude,
    ROUND(MAX(ST_Y(place_geometry)), 6) as max_latitude,
    ROUND(AVG(ST_X(place_geometry)), 6) as avg_longitude,
    ROUND(AVG(ST_Y(place_geometry)), 6) as avg_latitude
FROM poi_table 
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'Unmatched Places' as place_type,
    COUNT(*) as count,
    ROUND(MIN(ST_X(place_geometry)), 6) as min_longitude,
    ROUND(MAX(ST_X(place_geometry)), 6) as max_longitude,
    ROUND(MIN(ST_Y(place_geometry)), 6) as min_latitude,
    ROUND(MAX(ST_Y(place_geometry)), 6) as max_latitude,
    ROUND(AVG(ST_X(place_geometry)), 6) as avg_longitude,
    ROUND(AVG(ST_Y(place_geometry)), 6) as avg_latitude
FROM poi_table 
WHERE building_id IS NULL;

-- =============================================================================
-- 8. PERFORMANCE AND COMPLETENESS METRICS
-- =============================================================================

-- Data completeness assessment
SELECT 
    'Places with Names' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 2) as percentage
FROM poi_table 
WHERE place_name_clean != 'Unknown Place'

UNION ALL

SELECT 
    'Buildings with Names' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table WHERE building_id IS NOT NULL), 2) as percentage
FROM poi_table 
WHERE building_name_clean IS NOT NULL AND building_name_clean != 'Unknown Building'

UNION ALL

SELECT 
    'Places with Categories' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 2) as percentage
FROM poi_table 
WHERE place_categories IS NOT NULL

UNION ALL

SELECT 
    'Buildings with Height Data' as metric,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table WHERE building_id IS NOT NULL), 2) as percentage
FROM poi_table 
WHERE building_height IS NOT NULL;

-- Final summary report
SELECT 
    '=== POI MATCHING SUMMARY REPORT ===' as report_section,
    '' as details

UNION ALL

SELECT 
    'Total Places Processed:' as report_section,
    CAST(COUNT(*) AS TEXT) as details
FROM poi_table

UNION ALL

SELECT 
    'Successfully Matched:' as report_section,
    CAST(COUNT(*) AS TEXT) || ' (' || 
    CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table), 1) AS TEXT) || '%)' as details
FROM poi_table 
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'High Confidence Matches:' as report_section,
    CAST(COUNT(*) AS TEXT) || ' (' || 
    CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table WHERE building_id IS NOT NULL), 1) AS TEXT) || '% of matches)' as details
FROM poi_table 
WHERE match_quality IN ('EXACT_NAME_MATCH', 'HIGH_CONFIDENCE')

UNION ALL

SELECT 
    'Average Match Score:' as report_section,
    CAST(ROUND(AVG(composite_match_score), 3) AS TEXT) as details
FROM poi_table 
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'Average Distance:' as report_section,
    CAST(ROUND(AVG(distance_meters), 1) AS TEXT) || ' meters' as details
FROM poi_table 
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'Matches Requiring Review:' as report_section,
    CAST(COUNT(*) AS TEXT) || ' (' || 
    CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM poi_table WHERE building_id IS NOT NULL), 1) AS TEXT) || '% of matches)' as details
FROM poi_table 
WHERE match_quality IN ('LOW_CONFIDENCE', 'VERY_LOW_CONFIDENCE');

-- =============================================================================
-- 9. EXPORT QUERIES FOR FURTHER ANALYSIS
-- =============================================================================

-- Export high-quality matches for validation
-- Uncomment to create a sample file
/*
COPY (
    SELECT 
        place_id,
        building_id,
        place_name_clean,
        building_name_clean,
        match_quality,
        composite_match_score,
        distance_meters,
        ST_X(place_geometry) as place_longitude,
        ST_Y(place_geometry) as place_latitude,
        ST_X(ST_Centroid(building_geometry)) as building_longitude,
        ST_Y(ST_Centroid(building_geometry)) as building_latitude
    FROM poi_table 
    WHERE match_quality IN ('EXACT_NAME_MATCH', 'HIGH_CONFIDENCE')
    ORDER BY composite_match_score DESC
    LIMIT 1000
) TO '/tmp/high_quality_matches.csv' WITH CSV HEADER;
*/

-- Export problematic matches for manual review
-- Uncomment to create a sample file
/*
COPY (
    SELECT 
        place_id,
        building_id,
        place_name_clean,
        building_name_clean,
        match_quality,
        composite_match_score,
        distance_meters,
        name_similarity_score,
        spatial_relationship
    FROM poi_table 
    WHERE match_quality IN ('LOW_CONFIDENCE', 'VERY_LOW_CONFIDENCE')
       OR (match_quality = 'EXACT_NAME_MATCH' AND distance_meters > 50)
       OR distance_meters > 200
    ORDER BY composite_match_score ASC, distance_meters DESC
) TO '/tmp/problematic_matches.csv' WITH CSV HEADER;
*/