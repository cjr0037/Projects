-- ============================================================================
-- POI Matching Configuration Guide
-- ============================================================================
-- This file contains configurable parameters and alternative approaches
-- for the POI matching process
-- ============================================================================

-- ============================================================================
-- CONFIGURATION PARAMETERS
-- ============================================================================

-- Distance Threshold (meters)
-- How far from a building should we still consider it a match?
SET distance_threshold = 50;  -- Adjust: 25, 50, 100 meters

-- Name Similarity Threshold
-- Minimum Jaro-Winkler score to consider a name match (0-100 scale)
SET name_similarity_threshold = 70;  -- Adjust: 60, 70, 80

-- Scoring Weights (should sum to ~100)
SET weight_name_similarity = 60;      -- 60% weight on name matching
SET weight_spatial_proximity = 40;    -- 40% weight on distance
SET bonus_containment = 20;           -- Bonus points for spatial containment

-- ============================================================================
-- ALTERNATIVE MATCHING STRATEGY 1: Strict Spatial Containment
-- ============================================================================
-- Use this if you only want places that are actually inside buildings

CREATE OR REPLACE TABLE poi_table_strict AS
WITH spatial_matches AS (
    SELECT 
        p.*,
        b.id AS building_id,
        b.names AS building_names,
        b.geometry AS building_geometry,
        ST_DISTANCE(p.geometry, ST_CENTROID(b.geometry)) AS distance_to_center
    FROM overture_maps_places p
    INNER JOIN overture_maps_buildings b
        ON ST_CONTAINS(b.geometry, p.geometry)
)
SELECT 
    *,
    ROW_NUMBER() OVER (
        PARTITION BY id 
        ORDER BY distance_to_center ASC
    ) AS rank
FROM spatial_matches
QUALIFY rank = 1;

-- ============================================================================
-- ALTERNATIVE MATCHING STRATEGY 2: Name-Prioritized Matching
-- ============================================================================
-- Use this if name matching is more important than spatial proximity

CREATE OR REPLACE TABLE poi_table_name_priority AS
WITH name_matches AS (
    SELECT 
        p.id AS place_id,
        p.names,
        COALESCE(p.names:primary::STRING, '') AS place_name,
        p.geometry AS place_geometry,
        p.categories,
        p.confidence,
        p.websites,
        p.socials,
        p.emails,
        p.phones,
        p.addresses,
        
        b.id AS building_id,
        b.names AS building_names,
        COALESCE(b.names:primary::STRING, '') AS building_name,
        b.geometry AS building_geometry,
        
        JAROWINKLER_SIMILARITY(
            UPPER(TRIM(COALESCE(p.names:primary::STRING, ''))),
            UPPER(TRIM(COALESCE(b.names:primary::STRING, '')))
        ) AS name_score,
        
        ST_DISTANCE(p.geometry, b.geometry) AS distance
        
    FROM overture_maps_places p
    CROSS JOIN overture_maps_buildings b
    WHERE ST_DWITHIN(p.geometry, b.geometry, 100)
      AND name_score >= 75  -- High name similarity required
),
ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY name_score DESC, distance ASC
        ) AS rank
    FROM name_matches
)
SELECT * FROM ranked WHERE rank = 1;

-- ============================================================================
-- ALTERNATIVE MATCHING STRATEGY 3: Nearest Building (Spatial Only)
-- ============================================================================
-- Use this if you want to match each place to its nearest building regardless of name

CREATE OR REPLACE TABLE poi_table_nearest AS
WITH nearest_building AS (
    SELECT 
        p.id AS place_id,
        p.names AS place_names,
        p.geometry AS place_geometry,
        p.categories,
        p.confidence,
        p.websites,
        p.socials,
        p.emails,
        p.phones,
        p.addresses,
        
        b.id AS building_id,
        b.names AS building_names,
        b.geometry AS building_geometry,
        
        ST_DISTANCE(p.geometry, b.geometry) AS distance,
        ST_CONTAINS(b.geometry, p.geometry) AS is_contained,
        
        ROW_NUMBER() OVER (
            PARTITION BY p.id 
            ORDER BY 
                ST_CONTAINS(b.geometry, p.geometry) DESC,
                ST_DISTANCE(p.geometry, b.geometry) ASC
        ) AS rank
        
    FROM overture_maps_places p
    CROSS JOIN overture_maps_buildings b
    WHERE ST_DWITHIN(p.geometry, b.geometry, 100)
)
SELECT * FROM nearest_building WHERE rank = 1;

-- ============================================================================
-- UTILITY: Check for places with multiple building matches
-- ============================================================================

CREATE OR REPLACE VIEW places_with_multiple_matches AS
SELECT 
    place_id,
    place_name,
    COUNT(*) AS num_candidate_buildings,
    ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'building_id', building_id,
            'building_name', building_name,
            'distance', distance_meters,
            'name_similarity', name_similarity_score,
            'composite_score', composite_score
        )
    ) AS candidates
FROM scored_matches  -- References temp table from main script
GROUP BY place_id, place_name
HAVING COUNT(*) > 1
ORDER BY num_candidate_buildings DESC;

-- ============================================================================
-- UTILITY: Validate matching quality
-- ============================================================================

CREATE OR REPLACE VIEW matching_quality_report AS
SELECT 
    CASE 
        WHEN composite_score >= 90 THEN 'Excellent (90+)'
        WHEN composite_score >= 75 THEN 'Good (75-89)'
        WHEN composite_score >= 60 THEN 'Fair (60-74)'
        WHEN composite_score >= 40 THEN 'Poor (40-59)'
        ELSE 'Very Poor (<40)'
    END AS quality_tier,
    
    COUNT(*) AS num_pois,
    
    ROUND(AVG(name_similarity_score), 2) AS avg_name_similarity,
    ROUND(AVG(distance_meters), 2) AS avg_distance,
    
    SUM(CASE WHEN is_contained THEN 1 ELSE 0 END) AS num_contained,
    SUM(CASE WHEN distance_meters <= 10 THEN 1 ELSE 0 END) AS num_within_10m,
    SUM(CASE WHEN name_similarity_score >= 80 THEN 1 ELSE 0 END) AS num_name_match_80plus
    
FROM poi_table
WHERE building_id IS NOT NULL
GROUP BY quality_tier
ORDER BY 
    CASE quality_tier
        WHEN 'Excellent (90+)' THEN 1
        WHEN 'Good (75-89)' THEN 2
        WHEN 'Fair (60-74)' THEN 3
        WHEN 'Poor (40-59)' THEN 4
        ELSE 5
    END;

-- ============================================================================
-- UTILITY: Find potential mismatches for manual review
-- ============================================================================

CREATE OR REPLACE VIEW potential_mismatches AS
SELECT 
    place_id,
    place_name,
    building_id,
    building_name,
    distance_meters,
    name_similarity_score,
    composite_score,
    is_contained
FROM poi_table
WHERE building_id IS NOT NULL
  AND (
      -- Low composite score
      composite_score < 50 OR
      -- Name mismatch with spatial proximity
      (distance_meters < 5 AND name_similarity_score < 50) OR
      -- High distance with name match
      (distance_meters > 30 AND name_similarity_score > 80)
  )
ORDER BY composite_score ASC
LIMIT 500;

-- ============================================================================
-- PERFORMANCE OPTIMIZATION: Create spatial index
-- ============================================================================

-- Create clustering keys for better query performance
ALTER TABLE poi_table CLUSTER BY (LINEAR(ST_X(place_geometry), ST_Y(place_geometry)));

-- If your Snowflake account supports search optimization:
-- ALTER TABLE poi_table ADD SEARCH OPTIMIZATION ON EQUALITY(place_id, building_id);
-- ALTER TABLE poi_table ADD SEARCH OPTIMIZATION ON GEO(place_geometry);

-- ============================================================================
-- DATA QUALITY CHECKS
-- ============================================================================

-- Check for duplicate place_ids (shouldn't happen with ROW_NUMBER approach)
SELECT 
    place_id,
    COUNT(*) AS occurrences
FROM poi_table
GROUP BY place_id
HAVING COUNT(*) > 1;

-- Check for NULL geometries
SELECT 
    COUNT(*) AS null_place_geometries
FROM poi_table
WHERE place_geometry IS NULL;

-- Check distribution of match types
SELECT 
    CASE 
        WHEN building_id IS NULL THEN 'No Match'
        WHEN is_contained THEN 'Contained'
        WHEN distance_meters <= 5 THEN 'Adjacent (0-5m)'
        WHEN distance_meters <= 15 THEN 'Nearby (5-15m)'
        WHEN distance_meters <= 30 THEN 'Close (15-30m)'
        ELSE 'Distant (>30m)'
    END AS match_type,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM poi_table
GROUP BY match_type
ORDER BY count DESC;
