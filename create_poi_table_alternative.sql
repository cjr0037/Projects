-- Alternative POI Table Creation Script
-- This version provides compatibility with different SQL dialects and includes
-- alternative approaches for fuzzy matching when advanced functions aren't available

-- =============================================================================
-- CONFIGURATION SECTION
-- Adjust these parameters based on your specific requirements
-- =============================================================================

-- Distance threshold for considering buildings (in meters)
-- SET @max_distance_threshold = 100;

-- Minimum similarity score to consider a match valid
-- SET @min_similarity_threshold = 0.3;

-- =============================================================================
-- MAIN QUERY - Compatible with most SQL dialects
-- =============================================================================

CREATE TABLE poi_table AS
WITH spatial_candidates AS (
    -- Find all places and their potentially matching buildings within a reasonable distance
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
        
        -- Calculate distance using different approaches based on your SQL dialect
        -- For PostGIS:
        ST_Distance(
            ST_Transform(p.geometry, 3857), 
            ST_Transform(ST_Centroid(b.geometry), 3857)
        ) AS distance_meters,
        
        -- For other spatial databases, you might use:
        -- ST_Distance_Sphere(p.geometry, ST_Centroid(b.geometry)) AS distance_meters,
        
        ST_Area(ST_Transform(b.geometry, 3857)) AS building_area_sqm
        
    FROM overture_places p
    CROSS JOIN overture_buildings b
    WHERE 
        -- Spatial filter - adjust based on your spatial database capabilities
        ST_DWithin(
            ST_Transform(p.geometry, 3857), 
            ST_Transform(b.geometry, 3857), 
            100  -- 100 meter buffer
        )
        -- Alternative for databases without ST_DWithin:
        -- ST_Distance(ST_Transform(p.geometry, 3857), ST_Transform(b.geometry, 3857)) <= 100
),

name_extraction AS (
    -- Extract and clean names for comparison
    SELECT 
        *,
        -- Extract primary names - adjust JSON extraction based on your database
        COALESCE(
            -- For PostgreSQL with JSON support:
            NULLIF(TRIM(place_names->>'primary'), ''),
            NULLIF(TRIM(place_names->'common'->0->>'value'), ''),
            -- For databases without JSON operators, you might need to use:
            -- JSON_EXTRACT(place_names, '$.primary'),
            -- JSON_UNQUOTE(JSON_EXTRACT(place_names, '$.primary')),
            'Unknown Place'
        ) AS place_name_clean,
        
        COALESCE(
            NULLIF(TRIM(building_names->>'primary'), ''),
            NULLIF(TRIM(building_names->'common'->0->>'value'), ''),
            'Unknown Building'
        ) AS building_name_clean
        
    FROM spatial_candidates
),

similarity_calculation AS (
    -- Calculate similarity scores using available string functions
    SELECT 
        *,
        -- Basic similarity measures that work in most SQL dialects
        
        -- 1. Exact match (highest priority)
        CASE 
            WHEN UPPER(TRIM(place_name_clean)) = UPPER(TRIM(building_name_clean)) 
            THEN 1.0 
            ELSE 0.0 
        END AS exact_match_score,
        
        -- 2. Substring containment
        CASE 
            WHEN LENGTH(place_name_clean) >= 3 AND LENGTH(building_name_clean) >= 3 THEN
                CASE 
                    WHEN UPPER(place_name_clean) LIKE '%' || UPPER(building_name_clean) || '%' 
                        OR UPPER(building_name_clean) LIKE '%' || UPPER(place_name_clean) || '%' 
                    THEN 0.8 
                    ELSE 0.0 
                END
            ELSE 0.0
        END AS substring_score,
        
        -- 3. Word overlap score
        CASE 
            WHEN LENGTH(place_name_clean) >= 3 AND LENGTH(building_name_clean) >= 3 THEN
                -- Simple word overlap calculation
                CASE 
                    WHEN POSITION(' ' IN place_name_clean) > 0 AND POSITION(' ' IN building_name_clean) > 0 THEN
                        -- Both have multiple words - check for common words
                        CASE 
                            WHEN EXISTS (
                                SELECT 1 
                                WHERE UPPER(SPLIT_PART(place_name_clean, ' ', 1)) = UPPER(SPLIT_PART(building_name_clean, ' ', 1))
                                   OR UPPER(SPLIT_PART(place_name_clean, ' ', 1)) = UPPER(SPLIT_PART(building_name_clean, ' ', 2))
                                   OR UPPER(SPLIT_PART(place_name_clean, ' ', 2)) = UPPER(SPLIT_PART(building_name_clean, ' ', 1))
                            ) THEN 0.6
                            ELSE 0.0
                        END
                    ELSE 0.0
                END
            ELSE 0.0
        END AS word_overlap_score,
        
        -- 4. Length similarity bonus
        CASE 
            WHEN ABS(LENGTH(place_name_clean) - LENGTH(building_name_clean)) <= 2 
            THEN 0.1 
            ELSE 0.0 
        END AS length_similarity_bonus,
        
        -- 5. Distance score (exponential decay)
        CASE 
            WHEN distance_meters <= 10 THEN 1.0
            WHEN distance_meters <= 25 THEN 0.8
            WHEN distance_meters <= 50 THEN 0.6
            WHEN distance_meters <= 100 THEN 0.4
            ELSE 0.2
        END AS distance_score
        
    FROM name_extraction
),

composite_scoring AS (
    -- Calculate final composite scores
    SELECT 
        *,
        -- Weighted composite similarity score
        (
            exact_match_score * 0.4 +
            substring_score * 0.3 +
            word_overlap_score * 0.2 +
            length_similarity_bonus * 0.1
        ) AS name_similarity_score,
        
        -- Overall match score combining name similarity and distance
        (
            (exact_match_score * 0.4 + substring_score * 0.3 + word_overlap_score * 0.2 + length_similarity_bonus * 0.1) * 0.7 +
            distance_score * 0.3
        ) AS composite_match_score
        
    FROM similarity_calculation
),

ranked_matches AS (
    -- Rank matches for each place
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY 
                composite_match_score DESC,
                distance_meters ASC,
                building_area_sqm DESC NULLS LAST
        ) AS match_rank
        
    FROM composite_scoring
    WHERE composite_match_score >= 0.3  -- Filter out very poor matches
),

best_matches AS (
    -- Select the best match for each place
    SELECT * 
    FROM ranked_matches 
    WHERE match_rank = 1
),

unmatched_places AS (
    -- Include places without any building matches
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
        
        -- NULL building fields
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
        
        -- NULL metrics
        NULL AS distance_meters,
        NULL AS building_area_sqm,
        'Unknown Place' AS place_name_clean,
        NULL AS building_name_clean,
        0.0 AS exact_match_score,
        0.0 AS substring_score,
        0.0 AS word_overlap_score,
        0.0 AS length_similarity_bonus,
        0.0 AS distance_score,
        0.0 AS name_similarity_score,
        0.0 AS composite_match_score,
        1 AS match_rank
        
    FROM overture_places p
    WHERE p.id NOT IN (SELECT DISTINCT place_id FROM spatial_candidates)
)

-- Final result combining matched and unmatched places
SELECT 
    -- Core identifiers
    place_id,
    building_id,
    
    -- Place attributes
    place_names,
    place_categories,
    place_confidence,
    place_websites,
    place_socials,
    place_emails,
    place_phones,
    place_brand,
    place_addresses,
    place_sources,
    place_geometry,
    
    -- Building attributes
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
    building_sources,
    building_geometry,
    
    -- Cleaned names for reference
    place_name_clean,
    building_name_clean,
    
    -- Matching metrics
    distance_meters,
    building_area_sqm,
    exact_match_score,
    substring_score,
    word_overlap_score,
    length_similarity_bonus,
    distance_score,
    name_similarity_score,
    composite_match_score,
    
    -- Match quality classification
    CASE 
        WHEN building_id IS NULL THEN 'NO_BUILDING_MATCH'
        WHEN exact_match_score = 1.0 THEN 'EXACT_NAME_MATCH'
        WHEN composite_match_score >= 0.8 THEN 'HIGH_CONFIDENCE'
        WHEN composite_match_score >= 0.6 THEN 'MEDIUM_CONFIDENCE'
        WHEN composite_match_score >= 0.4 THEN 'LOW_CONFIDENCE'
        ELSE 'VERY_LOW_CONFIDENCE'
    END AS match_quality,
    
    -- Additional context
    CASE 
        WHEN building_id IS NOT NULL AND distance_meters <= 10 THEN 'INSIDE_OR_VERY_CLOSE'
        WHEN building_id IS NOT NULL AND distance_meters <= 50 THEN 'NEARBY'
        WHEN building_id IS NOT NULL THEN 'DISTANT'
        ELSE 'NO_SPATIAL_MATCH'
    END AS spatial_relationship,
    
    -- Metadata
    CURRENT_TIMESTAMP AS created_at,
    'overture_maps_v1' AS data_version
    
FROM (
    SELECT * FROM best_matches
    UNION ALL
    SELECT * FROM unmatched_places
) final_results

ORDER BY 
    place_id,
    composite_match_score DESC;

-- =============================================================================
-- POST-PROCESSING: Create indexes and generate statistics
-- =============================================================================

-- Primary indexes
CREATE INDEX IF NOT EXISTS idx_poi_place_id ON poi_table(place_id);
CREATE INDEX IF NOT EXISTS idx_poi_building_id ON poi_table(building_id) WHERE building_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_poi_match_quality ON poi_table(match_quality);
CREATE INDEX IF NOT EXISTS idx_poi_composite_score ON poi_table(composite_match_score) WHERE composite_match_score > 0;
CREATE INDEX IF NOT EXISTS idx_poi_spatial_relationship ON poi_table(spatial_relationship);

-- Spatial indexes (if supported)
-- CREATE INDEX IF NOT EXISTS idx_poi_place_geom ON poi_table USING GIST(place_geometry);
-- CREATE INDEX IF NOT EXISTS idx_poi_building_geom ON poi_table USING GIST(building_geometry) WHERE building_geometry IS NOT NULL;

-- Update table statistics
-- ANALYZE poi_table;  -- PostgreSQL
-- UPDATE STATISTICS poi_table;  -- SQL Server
-- ANALYZE TABLE poi_table;  -- MySQL