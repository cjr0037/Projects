# POI Spatial Matching: Overture Maps Places to Buildings

This repository contains Snowflake SQL queries to spatially match Overture Maps Places data to Buildings data, creating a comprehensive Points of Interest (POI) table with fuzzy name matching and distance-based ranking.

## Overview

The solution addresses the challenge of matching point-based place data to polygon-based building data, handling cases where:
- Multiple buildings may contain or be near a single place
- Place names may not exactly match building names
- Spatial relationships need to be combined with semantic similarity

## Files

### 1. `poi_spatial_matching.sql` (Recommended)
**Main comprehensive solution** with advanced features:
- Multi-factor scoring combining spatial, name, and categorical matching
- Uses both `EDITDISTANCE` and `JAROWINKLER_SIMILARITY` functions
- Handles substring matching and common abbreviations
- Provides quality assessment and confidence scoring
- Includes detailed match metadata

### 2. `poi_spatial_matching_simplified.sql`
**Simplified version** for basic use cases:
- Straightforward spatial join with basic fuzzy matching
- Uses only `EDITDISTANCE` for broader compatibility
- Easier to understand and modify
- Good starting point for customization

### 3. `poi_spatial_matching_advanced.sql`
**Most sophisticated version** with enterprise features:
- Comprehensive semantic matching
- Category-based matching bonuses
- Building size considerations
- Multiple name variation handling
- Detailed quality assessments

## Key Features

### Spatial Matching
- **Primary**: `ST_INTERSECTS` to find places within building polygons
- **Secondary**: `ST_DWITHIN` for proximity-based matching
- **Distance Calculation**: Both to building boundary and centroid
- **Containment Check**: `ST_CONTAINS` for perfect spatial matches

### Fuzzy Name Matching
- **Edit Distance**: Levenshtein distance for character-level similarity
- **Jaro-Winkler**: Phonetic similarity scoring
- **Substring Matching**: Handles partial name matches
- **Semantic Matching**: Common abbreviations and synonyms

### Ranking Algorithm
The composite scoring system weighs:
1. **Spatial Factors (50% weight)**:
   - Perfect containment: 25%
   - Intersection: 15%
   - Distance proximity: 10%

2. **Name Matching (40% weight)**:
   - Jaro-Winkler similarity: 20%
   - Edit distance: 10%
   - Semantic matching: 10%

3. **Category Matching (10% weight)**:
   - Business type alignment

## Usage

### Prerequisites
- Snowflake account with geospatial functions enabled
- Overture Maps data loaded into tables named:
  - `overture_maps.places`
  - `overture_maps.buildings`

### Basic Usage
```sql
-- Run the main query
-- Adjust table names to match your schema
SELECT * FROM (
    [INSERT QUERY FROM poi_spatial_matching.sql]
) 
LIMIT 1000;
```

### Creating Persistent Table
```sql
CREATE OR REPLACE TABLE my_schema.poi_places_buildings AS (
    [INSERT QUERY FROM poi_spatial_matching.sql]
);
```

## Expected Schema

### Places Table Expected Columns:
- `id`: Unique place identifier
- `names.primary`: Primary place name
- `names.common`: Alternative names (optional)
- `categories.primary`: Place category
- `geometry`: Point geometry (GEOGRAPHY type)
- `confidence`: Place confidence score (optional)
- `addresses`: Address information
- `phones`: Phone numbers
- `websites`: Website URLs
- `sources`: Data sources

### Buildings Table Expected Columns:
- `id`: Unique building identifier
- `names.primary`: Building name (may be null)
- `geometry`: Polygon geometry (GEOGRAPHY type)
- `class`: Building classification
- `height`: Building height (optional)
- `num_floors`: Number of floors (optional)

## Customization

### Adjusting Distance Thresholds
```sql
-- Change the proximity search radius (default: 100m)
ST_DWITHIN(p.geometry, b.geometry, 50)  -- 50 meters

-- Modify distance normalization
(100 - distance_to_building) / 100.0  -- Adjust 100 to your max distance
```

### Modifying Scoring Weights
```sql
-- Adjust the composite score formula weights
(
    0.4 * spatial_score +      -- 40% spatial (was 50%)
    0.5 * name_score +         -- 50% name matching (was 40%)
    0.1 * category_score       -- 10% category (unchanged)
)
```

### Quality Thresholds
```sql
-- Customize match quality categories
CASE 
    WHEN composite_score > 0.9 THEN 'EXCELLENT'    -- Raise threshold
    WHEN composite_score > 0.7 THEN 'GOOD'         -- Adjust as needed
    -- ... etc
END
```

## Performance Optimization

### Indexing Recommendations
```sql
-- Create spatial indexes
CREATE INDEX idx_places_geom ON overture_maps.places USING GEOGRAPHY(geometry);
CREATE INDEX idx_buildings_geom ON overture_maps.buildings USING GEOGRAPHY(geometry);

-- Create regular indexes on frequently filtered columns
CREATE INDEX idx_places_confidence ON overture_maps.places(confidence);
CREATE INDEX idx_buildings_class ON overture_maps.buildings(class);
```

### Query Optimization Tips
1. **Limit Search Radius**: Use smaller `ST_DWITHIN` distances when possible
2. **Filter Early**: Add WHERE clauses to reduce data volume
3. **Partition**: Consider partitioning large tables by geographic region
4. **Batch Processing**: Process data in geographic chunks for very large datasets

## Output Columns

The final result includes:
- **All original place metadata**: ID, name, category, geometry, addresses, etc.
- **Matched building information**: ID, name, geometry, classification, dimensions
- **Spatial relationship data**: Intersection status, distances, containment
- **Match quality metrics**: Scores, confidence levels, quality assessment
- **Algorithm metadata**: Timestamp, version information

## Match Quality Levels

- **EXCELLENT**: Perfect spatial and name match
- **VERY_GOOD**: Good spatial match with strong name similarity
- **GOOD**: Spatial intersection with reasonable name match
- **FAIR**: Close proximity with moderate name similarity
- **POOR**: Distant match or weak name similarity
- **VERY_POOR**: Low confidence matches (consider filtering out)

## Troubleshooting

### Common Issues
1. **No matches found**: Check geometry types and spatial reference systems
2. **Performance issues**: Reduce search radius or add geographic filters
3. **Name matching too strict**: Lower edit distance thresholds
4. **Too many poor matches**: Increase minimum score thresholds

### Validation Queries
```sql
-- Check match quality distribution
SELECT match_quality, COUNT(*) 
FROM poi_table 
GROUP BY match_quality;

-- Identify places without matches
SELECT COUNT(*) as unmatched_places
FROM overture_maps.places p
LEFT JOIN poi_table poi ON p.id = poi.place_id
WHERE poi.place_id IS NULL;
```

## License

This code is provided as-is for use with Overture Maps data. Please refer to Overture Maps licensing terms for data usage requirements.