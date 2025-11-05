-- ============================================================================
-- POI Table Creation: Overture Maps Places + Buildings Spatial Matching
-- ============================================================================
-- This script matches places (points) to buildings (polygons) using:
-- 1. Spatial containment/proximity
-- 2. Fuzzy name matching
-- 3. Distance to nearest building
-- ============================================================================

-- Step 1: Find all candidate matches (places within or near buildings)
-- Adjust the distance threshold as needed (e.g., 50 meters for nearby matches)
CREATE OR REPLACE TEMPORARY TABLE candidate_matches AS
SELECT 
    p.id AS place_id,
    p.names,
    p.categories,
    p.confidence,
    p.websites,
    p.socials,
    p.emails,
    p.phones,
    p.addresses,
    p.sources,
    p.geometry AS place_geometry,
    
    b.id AS building_id,
    b.names AS building_names,
    b.geometry AS building_geometry,
    
    -- Check if place is within building
    ST_CONTAINS(b.geometry, p.geometry) AS is_contained,
    
    -- Calculate distance from place point to building boundary
    ST_DISTANCE(p.geometry, b.geometry) AS distance_meters,
    
    -- Calculate distance to building centroid (alternative metric)
    ST_DISTANCE(p.geometry, ST_CENTROID(b.geometry)) AS distance_to_centroid
    
FROM overture_maps_places p
CROSS JOIN overture_maps_buildings b
WHERE 
    -- Spatial filter: only consider buildings within reasonable distance
    -- ST_DWITHIN uses meters for geography type
    ST_DWITHIN(p.geometry, b.geometry, 50) -- 50 meter threshold
;

-- Step 2: Calculate name similarity scores
CREATE OR REPLACE TEMPORARY TABLE scored_matches AS
SELECT 
    cm.*,
    
    -- Extract primary place name (assuming names is a VARIANT/JSON with 'primary' field)
    -- Adjust based on your actual schema
    COALESCE(
        cm.names:primary::STRING,
        cm.names:common[0].value::STRING,
        cm.names[0].value::STRING,
        ''
    ) AS place_name,
    
    -- Extract primary building name
    COALESCE(
        cm.building_names:primary::STRING,
        cm.building_names:common[0].value::STRING,
        cm.building_names[0].value::STRING,
        ''
    ) AS building_name,
    
    -- Fuzzy name matching using Jaro-Winkler similarity (0-100 scale)
    CASE 
        WHEN place_name = '' OR building_name = '' THEN 0
        ELSE JAROWINKLER_SIMILARITY(
            UPPER(TRIM(place_name)), 
            UPPER(TRIM(building_name))
        )
    END AS name_similarity_score,
    
    -- Alternative: Edit distance (lower is better)
    CASE 
        WHEN place_name = '' OR building_name = '' THEN 999
        ELSE EDITDISTANCE(
            UPPER(TRIM(place_name)), 
            UPPER(TRIM(building_name))
        )
    END AS edit_distance,
    
    -- Composite score: balance spatial proximity and name similarity
    -- Weight factors (adjust as needed):
    -- - 60% name similarity (0-100 scale)
    -- - 40% proximity (inverse of distance, normalized)
    -- - Bonus for containment
    (
        (name_similarity_score * 0.6) +
        (CASE 
            WHEN distance_meters = 0 THEN 40
            ELSE GREATEST(0, 40 * (1 - (distance_meters / 50)))
         END) +
        (CASE WHEN is_contained THEN 20 ELSE 0 END)
    ) AS composite_score
    
FROM candidate_matches cm
;

-- Step 3: Rank matches for each place and select the best one
CREATE OR REPLACE TEMPORARY TABLE ranked_matches AS
SELECT 
    *,
    ROW_NUMBER() OVER (
        PARTITION BY place_id 
        ORDER BY 
            composite_score DESC,
            is_contained DESC,
            distance_meters ASC,
            name_similarity_score DESC
    ) AS match_rank
FROM scored_matches
WHERE 
    -- Optional filters:
    -- Only keep reasonable matches (adjust thresholds as needed)
    (
        is_contained = TRUE OR 
        distance_meters <= 25 OR 
        name_similarity_score >= 70
    )
;

-- Step 4: Create final POI table with best matches
CREATE OR REPLACE TABLE poi_table AS
SELECT 
    -- Place information
    place_id,
    names AS place_names,
    place_name,
    categories,
    confidence,
    websites,
    socials,
    emails,
    phones,
    addresses,
    sources,
    place_geometry,
    
    -- Matched building information
    building_id,
    building_names,
    building_name,
    building_geometry,
    
    -- Match quality metrics
    is_contained,
    distance_meters,
    distance_to_centroid,
    name_similarity_score,
    edit_distance,
    composite_score,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS created_at
    
FROM ranked_matches
WHERE match_rank = 1  -- Only keep the best match per place
;

-- Step 5: Add places with no building matches (optional)
-- If you want to include places that didn't match any building
INSERT INTO poi_table
SELECT 
    p.id AS place_id,
    p.names AS place_names,
    COALESCE(
        p.names:primary::STRING,
        p.names:common[0].value::STRING,
        p.names[0].value::STRING
    ) AS place_name,
    p.categories,
    p.confidence,
    p.websites,
    p.socials,
    p.emails,
    p.phones,
    p.addresses,
    p.sources,
    p.geometry AS place_geometry,
    
    NULL AS building_id,
    NULL AS building_names,
    NULL AS building_name,
    NULL AS building_geometry,
    
    FALSE AS is_contained,
    NULL AS distance_meters,
    NULL AS distance_to_centroid,
    0 AS name_similarity_score,
    999 AS edit_distance,
    0 AS composite_score,
    
    CURRENT_TIMESTAMP() AS created_at
    
FROM overture_maps_places p
WHERE NOT EXISTS (
    SELECT 1 FROM ranked_matches rm 
    WHERE rm.place_id = p.id AND rm.match_rank = 1
)
;

-- ============================================================================
-- Summary Statistics
-- ============================================================================
SELECT 
    'Total POIs' AS metric,
    COUNT(*) AS count
FROM poi_table

UNION ALL

SELECT 
    'POIs with building match' AS metric,
    COUNT(*) AS count
FROM poi_table
WHERE building_id IS NOT NULL

UNION ALL

SELECT 
    'POIs contained in building' AS metric,
    COUNT(*) AS count
FROM poi_table
WHERE is_contained = TRUE

UNION ALL

SELECT 
    'POIs with high name similarity (>=80)' AS metric,
    COUNT(*) AS count
FROM poi_table
WHERE name_similarity_score >= 80

UNION ALL

SELECT 
    'POIs with no building match' AS metric,
    COUNT(*) AS count
FROM poi_table
WHERE building_id IS NULL
;

-- ============================================================================
-- Sample output to verify results
-- ============================================================================
SELECT 
    place_id,
    place_name,
    building_id,
    building_name,
    is_contained,
    ROUND(distance_meters, 2) AS dist_m,
    ROUND(name_similarity_score, 2) AS name_sim,
    ROUND(composite_score, 2) AS score
FROM poi_table
WHERE building_id IS NOT NULL
ORDER BY composite_score DESC
LIMIT 100;
