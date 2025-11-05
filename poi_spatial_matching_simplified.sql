-- Simplified Snowflake SQL Query for POI Spatial Matching
-- This is a more straightforward version focusing on the core requirements

WITH place_building_matches AS (
    SELECT 
        -- Place data
        p.id AS place_id,
        p.names.primary AS place_name,
        p.geometry AS place_geometry,
        p.categories.primary AS place_category,
        p.addresses,
        p.phones,
        p.websites,
        
        -- Building data
        b.id AS building_id,
        b.names.primary AS building_name,
        b.geometry AS building_geometry,
        b.class AS building_class,
        
        -- Spatial calculations
        ST_INTERSECTS(p.geometry, b.geometry) AS intersects,
        ST_DISTANCE(p.geometry, b.geometry) AS distance_meters,
        
        -- Name matching (using EDITDISTANCE as it's more widely available)
        COALESCE(
            EDITDISTANCE(
                UPPER(TRIM(p.names.primary)), 
                UPPER(TRIM(b.names.primary))
            ), 
            999
        ) AS name_edit_distance
        
    FROM overture_maps.places p
    JOIN overture_maps.buildings b 
        ON ST_DWITHIN(p.geometry, b.geometry, 50)  -- Within 50 meters
),

ranked_matches AS (
    SELECT 
        *,
        -- Combined ranking: prioritize intersection, then name similarity, then distance
        ROW_NUMBER() OVER (
            PARTITION BY place_id 
            ORDER BY 
                intersects DESC,           -- Intersecting buildings first
                name_edit_distance ASC,    -- Better name matches first  
                distance_meters ASC        -- Closer buildings first
        ) AS match_rank
    FROM place_building_matches
)

-- Final result: one building per place
SELECT 
    place_id,
    place_name,
    place_category,
    place_geometry,
    addresses,
    phones,
    websites,
    building_id,
    building_name,
    building_geometry,
    building_class,
    intersects AS place_intersects_building,
    distance_meters,
    name_edit_distance,
    CASE 
        WHEN intersects AND name_edit_distance <= 3 THEN 'EXCELLENT'
        WHEN intersects AND name_edit_distance <= 8 THEN 'GOOD'
        WHEN intersects THEN 'FAIR'
        WHEN distance_meters <= 10 AND name_edit_distance <= 5 THEN 'GOOD'
        WHEN distance_meters <= 25 THEN 'FAIR'
        ELSE 'POOR'
    END AS match_quality
FROM ranked_matches
WHERE match_rank = 1
ORDER BY place_id;