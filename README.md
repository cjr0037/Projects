# POI Table Creation: Overture Maps Places + Buildings Matching

This solution matches Overture Maps places (points) to buildings (polygons) using spatial proximity and fuzzy name matching to create a comprehensive POI (Point of Interest) table.

## Overview

The solution handles the common challenge where:
- A single place point might overlap with multiple building polygons
- Building and place names might not match exactly
- Some places might not be contained within any building polygon

## Files

### 1. `create_poi_table.sql`
Main script that creates the POI table with the best building match for each place.

**Key Features:**
- Spatial matching using `ST_CONTAINS` and `ST_DWITHIN`
- Fuzzy name matching using `JAROWINKLER_SIMILARITY`
- Composite scoring combining:
  - Name similarity (60% weight)
  - Spatial proximity (40% weight)
  - Containment bonus (20 points)
- Ranks matches and selects the best one per place
- Includes places with no building matches (optional)

### 2. `poi_matching_config.sql`
Configuration options and alternative matching strategies.

**Includes:**
- Configurable parameters (distance thresholds, weights)
- Alternative Strategy 1: Strict spatial containment only
- Alternative Strategy 2: Name-prioritized matching
- Alternative Strategy 3: Nearest building (spatial only)
- Quality validation views
- Performance optimization tips

## Prerequisites

Your Snowflake database should have:
- `overture_maps_places` table with columns:
  - `id` (place identifier)
  - `names` (VARIANT/JSON with name data)
  - `geometry` (GEOGRAPHY point)
  - `categories`, `confidence`, `websites`, `socials`, `emails`, `phones`, `addresses`, `sources`

- `overture_maps_buildings` table with columns:
  - `id` (building identifier)
  - `names` (VARIANT/JSON with name data)
  - `geometry` (GEOGRAPHY polygon)

## Usage

### Basic Usage

1. **Run the main script:**
```sql
-- Execute create_poi_table.sql
-- This will create the poi_table with best matches
```

2. **Review the results:**
```sql
SELECT * FROM poi_table LIMIT 100;
```

3. **Check the summary statistics** (automatically displayed at the end of the script)

### Customization

#### Adjust Distance Threshold

Change line in `create_poi_table.sql`:
```sql
ST_DWITHIN(p.geometry, b.geometry, 50) -- Change 50 to desired meters
```

#### Adjust Scoring Weights

Modify the composite score calculation:
```sql
(
    (name_similarity_score * 0.6) +  -- Change 0.6 for name weight
    (CASE 
        WHEN distance_meters = 0 THEN 40  -- Change 40 for distance weight
        ELSE GREATEST(0, 40 * (1 - (distance_meters / 50)))
     END) +
    (CASE WHEN is_contained THEN 20 ELSE 0 END)  -- Change 20 for containment bonus
)
```

#### Change Name Matching Threshold

Adjust the WHERE clause in Step 3:
```sql
WHERE 
    (
        is_contained = TRUE OR 
        distance_meters <= 25 OR 
        name_similarity_score >= 70  -- Change 70 to desired threshold
    )
```

### Alternative Approaches

If the default approach doesn't work well for your data:

1. **Strict Containment Only** - Use if you only want places inside buildings
2. **Name-Prioritized** - Use if name matching is more important than distance
3. **Nearest Building** - Use if you want purely spatial matching

See `poi_matching_config.sql` for these alternatives.

## Schema Details

### Output Table: `poi_table`

| Column | Type | Description |
|--------|------|-------------|
| `place_id` | VARCHAR | Place identifier |
| `place_names` | VARIANT | Place name data (JSON) |
| `place_name` | VARCHAR | Primary place name (extracted) |
| `categories` | VARIANT | Place categories |
| `confidence` | FLOAT | Confidence score |
| `websites` | VARIANT | Website URLs |
| `socials` | VARIANT | Social media links |
| `emails` | VARIANT | Email addresses |
| `phones` | VARIANT | Phone numbers |
| `addresses` | VARIANT | Address information |
| `sources` | VARIANT | Data sources |
| `place_geometry` | GEOGRAPHY | Place point geometry |
| `building_id` | VARCHAR | Matched building identifier |
| `building_names` | VARIANT | Building name data (JSON) |
| `building_name` | VARCHAR | Primary building name (extracted) |
| `building_geometry` | GEOGRAPHY | Building polygon geometry |
| `is_contained` | BOOLEAN | Whether place is inside building |
| `distance_meters` | FLOAT | Distance to building (meters) |
| `distance_to_centroid` | FLOAT | Distance to building center |
| `name_similarity_score` | FLOAT | Name match score (0-100) |
| `edit_distance` | INTEGER | Edit distance between names |
| `composite_score` | FLOAT | Overall match quality score |
| `created_at` | TIMESTAMP | Record creation timestamp |

## Quality Validation

### Check Matching Quality

```sql
-- View quality distribution
SELECT * FROM matching_quality_report;

-- Find potential mismatches
SELECT * FROM potential_mismatches;

-- See places with multiple candidate buildings
SELECT * FROM places_with_multiple_matches LIMIT 100;
```

### Common Adjustments Based on Results

**If too many places have no matches:**
- Increase distance threshold (e.g., from 50m to 100m)
- Lower name similarity threshold (e.g., from 70 to 60)

**If matches seem inaccurate:**
- Increase name similarity threshold
- Adjust scoring weights to favor name matching
- Use strict containment strategy

**If multiple buildings match the same place:**
- The script automatically picks the best one based on composite score
- Review `places_with_multiple_matches` view to see alternatives

## Performance Considerations

For large datasets:

1. **Add spatial clustering:**
```sql
ALTER TABLE poi_table CLUSTER BY (LINEAR(ST_X(place_geometry), ST_Y(place_geometry)));
```

2. **Use search optimization:**
```sql
ALTER TABLE poi_table ADD SEARCH OPTIMIZATION;
```

3. **Consider processing in batches** by geographic region:
```sql
-- Example: Process by bounding box
WHERE ST_WITHIN(p.geometry, ST_MAKEPOLYGON('LINESTRING(...)'))
```

## Troubleshooting

### Issue: Names extraction returns NULL
**Solution:** Check your `names` VARIANT structure:
```sql
SELECT names FROM overture_maps_places LIMIT 5;
```
Adjust the name extraction logic based on your schema.

### Issue: All distances are NULL
**Solution:** Ensure geometries are GEOGRAPHY type, not GEOMETRY:
```sql
ALTER TABLE overture_maps_places 
ALTER COLUMN geometry SET DATA TYPE GEOGRAPHY;
```

### Issue: Query times out
**Solution:** 
- Add WHERE clause to process subset of data
- Increase warehouse size
- Process in geographic batches

## Example Queries

### Find high-confidence matches
```sql
SELECT 
    place_name,
    building_name,
    composite_score,
    distance_meters
FROM poi_table
WHERE composite_score >= 90
ORDER BY composite_score DESC
LIMIT 100;
```

### Find places in specific category
```sql
SELECT 
    place_name,
    building_name,
    categories
FROM poi_table
WHERE categories:primary::STRING = 'restaurant'
  AND building_id IS NOT NULL;
```

### Export for analysis
```sql
SELECT 
    place_id,
    place_name,
    building_id,
    ST_ASGEOJSON(building_geometry) AS building_geojson,
    composite_score
FROM poi_table
WHERE composite_score >= 80;
```

## Notes

- The script creates temporary tables during processing which are automatically cleaned up
- Duplicate place_ids in the final table should not occur (each place matched to at most one building)
- NULL building_id indicates no suitable building match was found
- Adjust thresholds based on your data quality and matching requirements

## Support

For issues or questions about:
- Overture Maps data schema: https://docs.overturemaps.org/
- Snowflake spatial functions: https://docs.snowflake.com/en/sql-reference/functions-geospatial
