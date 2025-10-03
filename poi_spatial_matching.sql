-- Snowflake SQL Query to Create POI Table by Spatially Matching Overture Maps Places to Buildings
-- This query combines spatial matching, fuzzy name matching, and distance-based ranking
-- to select the best building match for each place

-- Step 1: Create the main spatial matching CTE with all potential matches
WITH spatial_matches AS (
    SELECT 
        -- Place attributes
        p.id AS place_id,
        p.names.primary AS place_name,
        p.categories.primary AS place_category,
        p.confidence AS place_confidence,
        p.geometry AS place_geometry,
        p.addresses,
        p.phones,
        p.websites,
        p.sources,
        
        -- Building attributes  
        b.id AS building_id,
        b.names.primary AS building_name,
        b.geometry AS building_geometry,
        b.height,
        b.num_floors,
        b.class AS building_class,
        
        -- Calculate spatial relationship and distance
        ST_INTERSECTS(p.geometry, b.geometry) AS is_intersecting,
        ST_DISTANCE(p.geometry, ST_CENTROID(b.geometry)) AS distance_to_centroid,
        ST_DISTANCE(p.geometry, b.geometry) AS distance_to_building
        
    FROM overture_maps.places p
    CROSS JOIN overture_maps.buildings b
    WHERE 
        -- Spatial filter: only consider buildings within reasonable distance (e.g., 100 meters)
        ST_DWITHIN(p.geometry, b.geometry, 100)
),

-- Step 2: Add fuzzy name matching scores
fuzzy_matches AS (
    SELECT 
        *,
        -- Calculate various name similarity metrics
        CASE 
            WHEN place_name IS NOT NULL AND building_name IS NOT NULL THEN
                EDITDISTANCE(UPPER(TRIM(place_name)), UPPER(TRIM(building_name)))
            ELSE 999
        END AS edit_distance,
        
        CASE 
            WHEN place_name IS NOT NULL AND building_name IS NOT NULL THEN
                JAROWINKLER_SIMILARITY(UPPER(TRIM(place_name)), UPPER(TRIM(building_name)))
            ELSE 0
        END AS jaro_winkler_score,
        
        -- Check for exact substring matches
        CASE 
            WHEN place_name IS NOT NULL AND building_name IS NOT NULL THEN
                CASE 
                    WHEN UPPER(TRIM(place_name)) = UPPER(TRIM(building_name)) THEN 1.0
                    WHEN CONTAINS(UPPER(TRIM(building_name)), UPPER(TRIM(place_name))) THEN 0.8
                    WHEN CONTAINS(UPPER(TRIM(place_name)), UPPER(TRIM(building_name))) THEN 0.8
                    ELSE 0.0
                END
            ELSE 0.0
        END AS substring_match_score
        
    FROM spatial_matches
),

-- Step 3: Calculate composite matching scores and rank matches
ranked_matches AS (
    SELECT 
        *,
        -- Normalize distance (assuming max reasonable distance is 100m)
        GREATEST(0, (100 - distance_to_building) / 100.0) AS normalized_distance_score,
        
        -- Create composite score combining multiple factors
        (
            -- Intersection bonus (40% weight)
            CASE WHEN is_intersecting THEN 0.4 ELSE 0.0 END +
            
            -- Distance score (30% weight) 
            0.3 * GREATEST(0, (100 - distance_to_building) / 100.0) +
            
            -- Jaro-Winkler similarity (20% weight)
            0.2 * jaro_winkler_score +
            
            -- Substring match bonus (10% weight)
            0.1 * substring_match_score +
            
            -- Edit distance penalty (lower is better, convert to 0-1 scale)
            0.05 * GREATEST(0, (20 - edit_distance) / 20.0)
            
        ) AS composite_score,
        
        -- Rank matches for each place
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY 
                is_intersecting DESC,  -- Prioritize intersecting buildings
                composite_score DESC,  -- Then by composite score
                distance_to_building ASC,  -- Then by distance
                edit_distance ASC  -- Finally by name similarity
        ) AS match_rank
        
    FROM fuzzy_matches
),

-- Step 4: Select best matches and add quality indicators
best_matches AS (
    SELECT 
        *,
        -- Add match quality indicators
        CASE 
            WHEN is_intersecting AND jaro_winkler_score > 0.8 THEN 'HIGH'
            WHEN is_intersecting AND jaro_winkler_score > 0.6 THEN 'MEDIUM_HIGH'
            WHEN is_intersecting THEN 'MEDIUM'
            WHEN distance_to_building < 10 AND jaro_winkler_score > 0.7 THEN 'MEDIUM'
            WHEN distance_to_building < 25 THEN 'LOW_MEDIUM'
            ELSE 'LOW'
        END AS match_quality,
        
        -- Add confidence score
        CASE 
            WHEN composite_score > 0.8 THEN 'VERY_HIGH'
            WHEN composite_score > 0.6 THEN 'HIGH'
            WHEN composite_score > 0.4 THEN 'MEDIUM'
            WHEN composite_score > 0.2 THEN 'LOW'
            ELSE 'VERY_LOW'
        END AS match_confidence
        
    FROM ranked_matches
    WHERE match_rank = 1  -- Only keep the best match for each place
)

-- Final SELECT: Create the POI table with all place metadata and matched building info
SELECT 
    -- Place identification and metadata
    place_id,
    place_name,
    place_category,
    place_confidence,
    place_geometry,
    addresses,
    phones,
    websites,
    sources,
    
    -- Matched building information
    building_id,
    building_name,
    building_geometry,
    height AS building_height,
    num_floors AS building_floors,
    building_class,
    
    -- Matching metrics and quality indicators
    is_intersecting,
    distance_to_building,
    distance_to_centroid,
    edit_distance,
    jaro_winkler_score,
    substring_match_score,
    composite_score,
    match_quality,
    match_confidence,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS created_at,
    'spatial_fuzzy_match_v1' AS matching_algorithm
    
FROM best_matches
ORDER BY 
    match_quality DESC,
    composite_score DESC,
    place_id;

-- Optional: Create the table if you want to persist results
-- CREATE OR REPLACE TABLE poi_places_buildings AS (
--     [INSERT THE ABOVE QUERY HERE]
-- );

-- Optional: Add some summary statistics
-- SELECT 
--     match_quality,
--     match_confidence,
--     COUNT(*) as match_count,
--     AVG(composite_score) as avg_composite_score,
--     AVG(distance_to_building) as avg_distance,
--     AVG(jaro_winkler_score) as avg_name_similarity
-- FROM poi_places_buildings
-- GROUP BY match_quality, match_confidence
-- ORDER BY match_quality DESC, match_confidence DESC;