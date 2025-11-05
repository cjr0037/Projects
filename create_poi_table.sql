-- POI Table Creation with Spatial Matching between Overture Maps Places and Buildings
-- This script creates a comprehensive POI table by spatially matching places to buildings
-- using fuzzy name matching and distance calculations to find the best matches

-- First, let's create a comprehensive matching query that handles the spatial join
-- and applies fuzzy matching with distance-based ranking

WITH spatial_matches AS (
    -- Step 1: Find all spatial intersections between places and buildings
    SELECT 
        p.id AS place_id,
        p.names AS place_names,
        p.categories AS place_categories,
        p.confidence AS place_confidence,
        p.websites AS place_websites,
        p.socials AS place_socials,
        p.emails AS place_emails,
        p.phones AS place_phones,
        p.brand AS place_brand,
        p.addresses AS place_addresses,
        p.sources AS place_sources,
        p.geometry AS place_geometry,
        
        b.id AS building_id,
        b.names AS building_names,
        b.height AS building_height,
        b.num_floors AS building_num_floors,
        b.level AS building_level,
        b.facade_color AS building_facade_color,
        b.facade_material AS building_facade_material,
        b.roof_material AS building_roof_material,
        b.roof_shape AS building_roof_shape,
        b.roof_direction AS building_roof_direction,
        b.roof_color AS building_roof_color,
        b.sources AS building_sources,
        b.geometry AS building_geometry,
        
        -- Calculate distance between place point and building centroid
        ST_Distance(
            ST_Transform(p.geometry, 3857), 
            ST_Transform(ST_Centroid(b.geometry), 3857)
        ) AS distance_meters,
        
        -- Calculate area of building for context
        ST_Area(ST_Transform(b.geometry, 3857)) AS building_area_sqm
        
    FROM overture_places p
    JOIN overture_buildings b ON ST_Intersects(p.geometry, b.geometry)
    
    -- Optional: Add buffer around places to catch nearby buildings
    -- Uncomment the line below and comment the line above if you want to include nearby buildings
    -- JOIN overture_buildings b ON ST_Intersects(ST_Buffer(p.geometry, 0.0001), b.geometry)
),

name_similarity_scores AS (
    -- Step 2: Calculate name similarity scores using various string matching techniques
    SELECT 
        *,
        -- Extract primary names for comparison (assuming JSON structure)
        COALESCE(
            JSON_EXTRACT_SCALAR(place_names, '$.primary'),
            JSON_EXTRACT_SCALAR(place_names, '$.common[0].value'),
            'Unknown Place'
        ) AS place_primary_name,
        
        COALESCE(
            JSON_EXTRACT_SCALAR(building_names, '$.primary'),
            JSON_EXTRACT_SCALAR(building_names, '$.common[0].value'),
            'Unknown Building'
        ) AS building_primary_name
        
    FROM spatial_matches
),

fuzzy_matching_scores AS (
    -- Step 3: Apply fuzzy matching algorithms
    SELECT 
        *,
        -- Levenshtein distance (lower is better, normalize to 0-1 scale)
        CASE 
            WHEN LENGTH(place_primary_name) = 0 OR LENGTH(building_primary_name) = 0 THEN 0
            ELSE 1.0 - (CAST(LEVENSHTEIN(
                UPPER(TRIM(place_primary_name)), 
                UPPER(TRIM(building_primary_name))
            ) AS FLOAT) / GREATEST(LENGTH(place_primary_name), LENGTH(building_primary_name)))
        END AS levenshtein_similarity,
        
        -- Jaro-Winkler similarity (higher is better, 0-1 scale)
        JARO_WINKLER_SIMILARITY(
            UPPER(TRIM(place_primary_name)), 
            UPPER(TRIM(building_primary_name))
        ) AS jaro_winkler_similarity,
        
        -- Simple substring matching
        CASE 
            WHEN UPPER(place_primary_name) LIKE '%' || UPPER(building_primary_name) || '%' 
                OR UPPER(building_primary_name) LIKE '%' || UPPER(place_primary_name) || '%' 
            THEN 1.0 
            ELSE 0.0 
        END AS substring_match,
        
        -- Exact match bonus
        CASE 
            WHEN UPPER(TRIM(place_primary_name)) = UPPER(TRIM(building_primary_name)) 
            THEN 1.0 
            ELSE 0.0 
        END AS exact_match
        
    FROM name_similarity_scores
),

distance_normalized_scores AS (
    -- Step 4: Normalize distance scores and create composite matching score
    SELECT 
        *,
        -- Normalize distance (closer is better, convert to 0-1 scale)
        -- Using exponential decay: closer distances get higher scores
        EXP(-distance_meters / 50.0) AS distance_score,
        
        -- Create composite similarity score
        (
            levenshtein_similarity * 0.3 +
            jaro_winkler_similarity * 0.3 +
            substring_match * 0.2 +
            exact_match * 0.2
        ) AS name_similarity_score
        
    FROM fuzzy_matching_scores
),

final_scores AS (
    -- Step 5: Calculate final matching scores and rank matches
    SELECT 
        *,
        -- Composite matching score (name similarity weighted more heavily than distance)
        (name_similarity_score * 0.7 + distance_score * 0.3) AS composite_match_score,
        
        -- Rank matches for each place (best match gets rank 1)
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY 
                (name_similarity_score * 0.7 + distance_score * 0.3) DESC,
                distance_meters ASC,
                building_area_sqm DESC
        ) AS match_rank
        
    FROM distance_normalized_scores
),

best_matches AS (
    -- Step 6: Select only the best match for each place
    SELECT * 
    FROM final_scores 
    WHERE match_rank = 1
),

places_without_buildings AS (
    -- Step 7: Include places that don't have any building matches
    SELECT 
        p.id AS place_id,
        p.names AS place_names,
        p.categories AS place_categories,
        p.confidence AS place_confidence,
        p.websites AS place_websites,
        p.socials AS place_socials,
        p.emails AS place_emails,
        p.phones AS place_phones,
        p.brand AS place_brand,
        p.addresses AS place_addresses,
        p.sources AS place_sources,
        p.geometry AS place_geometry,
        
        NULL AS building_id,
        NULL AS building_names,
        NULL AS building_height,
        NULL AS building_num_floors,
        NULL AS building_level,
        NULL AS building_facade_color,
        NULL AS building_facade_material,
        NULL AS building_roof_material,
        NULL AS building_roof_shape,
        NULL AS building_roof_direction,
        NULL AS building_roof_color,
        NULL AS building_sources,
        NULL AS building_geometry,
        
        NULL AS distance_meters,
        NULL AS building_area_sqm,
        NULL AS place_primary_name,
        NULL AS building_primary_name,
        NULL AS levenshtein_similarity,
        NULL AS jaro_winkler_similarity,
        NULL AS substring_match,
        NULL AS exact_match,
        NULL AS distance_score,
        NULL AS name_similarity_score,
        NULL AS composite_match_score,
        1 AS match_rank
        
    FROM overture_places p
    WHERE p.id NOT IN (SELECT DISTINCT place_id FROM spatial_matches)
)

-- Final POI table creation
CREATE TABLE poi_table AS
SELECT 
    -- Place information
    place_id,
    place_names,
    place_categories,
    place_confidence,
    place_websites,
    place_socials,
    place_emails,
    place_phones,
    place_brand,
    place_addresses,
    place_sources AS place_sources,
    place_geometry,
    
    -- Building information (NULL if no match)
    building_id,
    building_names,
    building_height,
    building_num_floors,
    building_level,
    building_facade_color,
    building_facade_material,
    building_roof_material,
    building_roof_shape,
    building_roof_direction,
    building_roof_color,
    building_sources AS building_sources,
    building_geometry,
    
    -- Matching metadata
    distance_meters,
    building_area_sqm,
    place_primary_name,
    building_primary_name,
    levenshtein_similarity,
    jaro_winkler_similarity,
    substring_match,
    exact_match,
    name_similarity_score,
    distance_score,
    composite_match_score,
    
    -- Match quality indicators
    CASE 
        WHEN building_id IS NULL THEN 'NO_BUILDING_MATCH'
        WHEN composite_match_score >= 0.8 THEN 'HIGH_CONFIDENCE'
        WHEN composite_match_score >= 0.6 THEN 'MEDIUM_CONFIDENCE'
        WHEN composite_match_score >= 0.4 THEN 'LOW_CONFIDENCE'
        ELSE 'VERY_LOW_CONFIDENCE'
    END AS match_quality,
    
    -- Timestamp
    CURRENT_TIMESTAMP AS created_at
    
FROM (
    SELECT * FROM best_matches
    UNION ALL
    SELECT * FROM places_without_buildings
) combined_results

ORDER BY 
    place_id,
    composite_match_score DESC NULLS LAST;

-- Create indexes for better performance
CREATE INDEX idx_poi_place_id ON poi_table(place_id);
CREATE INDEX idx_poi_building_id ON poi_table(building_id);
CREATE INDEX idx_poi_match_quality ON poi_table(match_quality);
CREATE INDEX idx_poi_composite_score ON poi_table(composite_match_score);

-- Create spatial indexes
CREATE INDEX idx_poi_place_geometry ON poi_table USING GIST(place_geometry);
CREATE INDEX idx_poi_building_geometry ON poi_table USING GIST(building_geometry);

-- Add table statistics
ANALYZE poi_table;

-- Summary statistics query
SELECT 
    match_quality,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(composite_match_score), 3) AS avg_match_score,
    ROUND(AVG(distance_meters), 2) AS avg_distance_meters
FROM poi_table 
GROUP BY match_quality
ORDER BY 
    CASE match_quality
        WHEN 'HIGH_CONFIDENCE' THEN 1
        WHEN 'MEDIUM_CONFIDENCE' THEN 2
        WHEN 'LOW_CONFIDENCE' THEN 3
        WHEN 'VERY_LOW_CONFIDENCE' THEN 4
        WHEN 'NO_BUILDING_MATCH' THEN 5
    END;

-- Sample query to view results
SELECT 
    place_id,
    place_primary_name,
    building_primary_name,
    match_quality,
    ROUND(composite_match_score, 3) AS match_score,
    ROUND(distance_meters, 2) AS distance_m,
    ROUND(building_area_sqm, 2) AS building_area_sqm
FROM poi_table 
WHERE match_quality != 'NO_BUILDING_MATCH'
ORDER BY composite_match_score DESC
LIMIT 20;