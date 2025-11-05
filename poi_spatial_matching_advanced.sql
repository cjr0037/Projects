-- Advanced POI Spatial Matching with Multiple Fuzzy Matching Techniques
-- This version includes more sophisticated matching algorithms and handles edge cases

-- First, let's create a function to normalize names for better matching
-- (This would need to be created as a UDF in Snowflake)
/*
CREATE OR REPLACE FUNCTION normalize_name(input_name STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
    SELECT REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                UPPER(TRIM(input_name)),
                '[^A-Z0-9\\s]', ''  -- Remove special characters
            ),
            '\\s+', ' '  -- Normalize whitespace
        ),
        '\\b(THE|AND|OF|IN|AT|ON|FOR)\\b', ''  -- Remove common words
    )
$$;
*/

WITH enhanced_spatial_matches AS (
    SELECT 
        -- Place attributes
        p.id AS place_id,
        p.names.primary AS place_name,
        p.names.common AS place_common_names,
        p.categories.primary AS place_category,
        p.categories.alternate AS place_alt_categories,
        p.confidence AS place_confidence,
        p.geometry AS place_geometry,
        p.addresses,
        p.phones,
        p.websites,
        p.sources,
        
        -- Building attributes  
        b.id AS building_id,
        b.names.primary AS building_name,
        b.names.common AS building_common_names,
        b.geometry AS building_geometry,
        b.height,
        b.num_floors,
        b.class AS building_class,
        b.sources AS building_sources,
        
        -- Spatial relationships
        ST_INTERSECTS(p.geometry, b.geometry) AS is_intersecting,
        ST_CONTAINS(b.geometry, p.geometry) AS building_contains_place,
        ST_DISTANCE(p.geometry, ST_CENTROID(b.geometry)) AS distance_to_centroid,
        ST_DISTANCE(p.geometry, b.geometry) AS distance_to_building,
        ST_AREA(b.geometry) AS building_area
        
    FROM overture_maps.places p
    CROSS JOIN overture_maps.buildings b
    WHERE 
        -- Spatial filter with larger radius for comprehensive matching
        ST_DWITHIN(p.geometry, b.geometry, 200)
        -- Optional: Filter by place confidence if available
        AND (p.confidence IS NULL OR p.confidence >= 0.5)
),

-- Enhanced fuzzy matching with multiple name variations
comprehensive_fuzzy_matches AS (
    SELECT 
        *,
        -- Primary name matching
        COALESCE(
            EDITDISTANCE(
                UPPER(REGEXP_REPLACE(TRIM(place_name), '[^A-Z0-9\\s]', '')),
                UPPER(REGEXP_REPLACE(TRIM(building_name), '[^A-Z0-9\\s]', ''))
            ), 
            999
        ) AS primary_edit_distance,
        
        COALESCE(
            JAROWINKLER_SIMILARITY(
                UPPER(TRIM(place_name)),
                UPPER(TRIM(building_name))
            ),
            0
        ) AS primary_jaro_winkler,
        
        -- Check for partial matches and common abbreviations
        CASE 
            WHEN place_name IS NULL OR building_name IS NULL THEN 0
            WHEN UPPER(TRIM(place_name)) = UPPER(TRIM(building_name)) THEN 1.0
            WHEN CONTAINS(UPPER(building_name), UPPER(TRIM(place_name))) THEN 0.9
            WHEN CONTAINS(UPPER(place_name), UPPER(TRIM(building_name))) THEN 0.9
            -- Check for common abbreviations
            WHEN (CONTAINS(UPPER(place_name), 'RESTAURANT') AND CONTAINS(UPPER(building_name), 'REST'))
                OR (CONTAINS(UPPER(place_name), 'BUILDING') AND CONTAINS(UPPER(building_name), 'BLDG'))
                OR (CONTAINS(UPPER(place_name), 'CENTER') AND CONTAINS(UPPER(building_name), 'CTR'))
                OR (CONTAINS(UPPER(place_name), 'STREET') AND CONTAINS(UPPER(building_name), 'ST'))
                THEN 0.8
            ELSE 0.0
        END AS semantic_match_score,
        
        -- Category-based matching boost
        CASE 
            WHEN place_category IS NOT NULL AND building_class IS NOT NULL THEN
                CASE 
                    WHEN (CONTAINS(UPPER(place_category), 'RETAIL') AND CONTAINS(UPPER(building_class), 'COMMERCIAL'))
                        OR (CONTAINS(UPPER(place_category), 'RESTAURANT') AND CONTAINS(UPPER(building_class), 'COMMERCIAL'))
                        OR (CONTAINS(UPPER(place_category), 'OFFICE') AND CONTAINS(UPPER(building_class), 'OFFICE'))
                        OR (CONTAINS(UPPER(place_category), 'RESIDENTIAL') AND CONTAINS(UPPER(building_class), 'RESIDENTIAL'))
                        THEN 0.2
                    ELSE 0.0
                END
            ELSE 0.0
        END AS category_match_bonus
        
    FROM enhanced_spatial_matches
),

-- Advanced scoring with weighted factors
advanced_scoring AS (
    SELECT 
        *,
        -- Normalize distance scores
        CASE 
            WHEN distance_to_building = 0 THEN 1.0
            WHEN distance_to_building <= 200 THEN GREATEST(0, (200 - distance_to_building) / 200.0)
            ELSE 0.0
        END AS normalized_distance_score,
        
        -- Normalize edit distance (assuming max reasonable edit distance is 20)
        GREATEST(0, (20 - primary_edit_distance) / 20.0) AS normalized_edit_score,
        
        -- Calculate comprehensive composite score
        (
            -- Spatial factors (50% total weight)
            CASE WHEN building_contains_place THEN 0.25 ELSE 0.0 END +  -- Perfect spatial match
            CASE WHEN is_intersecting THEN 0.15 ELSE 0.0 END +          -- Intersection bonus
            0.10 * CASE 
                WHEN distance_to_building = 0 THEN 1.0
                WHEN distance_to_building <= 200 THEN (200 - distance_to_building) / 200.0
                ELSE 0.0
            END +
            
            -- Name matching factors (40% total weight)
            0.20 * primary_jaro_winkler +                               -- Jaro-Winkler similarity
            0.10 * GREATEST(0, (20 - primary_edit_distance) / 20.0) +  -- Edit distance
            0.10 * semantic_match_score +                               -- Semantic matching
            
            -- Category matching (10% total weight)
            0.10 * category_match_bonus
            
        ) AS comprehensive_score,
        
        -- Building size factor (larger buildings might be more likely matches for businesses)
        CASE 
            WHEN building_area > 10000 THEN 0.05  -- Large building bonus
            WHEN building_area > 1000 THEN 0.02   -- Medium building bonus
            ELSE 0.0
        END AS building_size_bonus
        
    FROM comprehensive_fuzzy_matches
),

-- Final ranking with comprehensive scoring
final_ranking AS (
    SELECT 
        *,
        comprehensive_score + building_size_bonus AS final_score,
        
        -- Rank matches for each place
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY 
                building_contains_place DESC,    -- Perfect spatial containment first
                is_intersecting DESC,            -- Then intersection
                comprehensive_score + building_size_bonus DESC,  -- Then comprehensive score
                distance_to_building ASC,        -- Then distance
                primary_edit_distance ASC        -- Finally name similarity
        ) AS final_rank,
        
        -- Quality assessment
        CASE 
            WHEN building_contains_place AND primary_jaro_winkler > 0.8 THEN 'EXCELLENT'
            WHEN building_contains_place AND primary_jaro_winkler > 0.6 THEN 'VERY_GOOD'
            WHEN building_contains_place OR (is_intersecting AND primary_jaro_winkler > 0.7) THEN 'GOOD'
            WHEN is_intersecting AND primary_jaro_winkler > 0.5 THEN 'FAIR'
            WHEN distance_to_building <= 10 AND primary_jaro_winkler > 0.6 THEN 'FAIR'
            WHEN distance_to_building <= 25 AND primary_jaro_winkler > 0.4 THEN 'POOR'
            ELSE 'VERY_POOR'
        END AS match_quality_assessment
        
    FROM advanced_scoring
)

-- Final output with the best match for each place
SELECT 
    -- Place identification and core data
    place_id,
    place_name,
    place_common_names,
    place_category,
    place_alt_categories,
    place_confidence,
    place_geometry,
    addresses,
    phones,
    websites,
    sources AS place_sources,
    
    -- Matched building information
    building_id,
    building_name,
    building_common_names,
    building_geometry,
    height AS building_height,
    num_floors AS building_floors,
    building_class,
    building_area,
    building_sources,
    
    -- Spatial relationship details
    is_intersecting,
    building_contains_place,
    distance_to_building,
    distance_to_centroid,
    
    -- Matching quality metrics
    primary_edit_distance,
    primary_jaro_winkler,
    semantic_match_score,
    category_match_bonus,
    comprehensive_score,
    building_size_bonus,
    final_score,
    match_quality_assessment,
    
    -- Additional metadata
    CURRENT_TIMESTAMP() AS match_timestamp,
    'advanced_spatial_fuzzy_v2' AS matching_algorithm_version
    
FROM final_ranking
WHERE final_rank = 1  -- Only the best match per place
ORDER BY 
    match_quality_assessment DESC,
    final_score DESC,
    place_id;

-- Optional: Summary statistics query
/*
SELECT 
    match_quality_assessment,
    COUNT(*) as place_count,
    AVG(final_score) as avg_final_score,
    AVG(distance_to_building) as avg_distance_meters,
    AVG(primary_jaro_winkler) as avg_name_similarity,
    SUM(CASE WHEN is_intersecting THEN 1 ELSE 0 END) as intersecting_matches,
    SUM(CASE WHEN building_contains_place THEN 1 ELSE 0 END) as contained_matches
FROM [result_table_name]
GROUP BY match_quality_assessment
ORDER BY 
    CASE match_quality_assessment
        WHEN 'EXCELLENT' THEN 1
        WHEN 'VERY_GOOD' THEN 2
        WHEN 'GOOD' THEN 3
        WHEN 'FAIR' THEN 4
        WHEN 'POOR' THEN 5
        WHEN 'VERY_POOR' THEN 6
    END;
*/