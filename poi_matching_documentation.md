# POI Table Creation with Overture Maps Data

This project creates a comprehensive Points of Interest (POI) table by spatially matching Overture Maps places with buildings, using advanced fuzzy name matching and distance calculations to determine the best matches.

## Overview

The solution addresses the challenge of matching point-based place data with polygon-based building data, where:
- Individual places may overlap with multiple buildings
- Name variations and inconsistencies require fuzzy matching
- Distance-based ranking helps identify the most likely building association
- Some places may not have corresponding buildings

## Key Features

### 1. Spatial Matching
- Uses spatial intersection and distance calculations
- Configurable distance thresholds for candidate selection
- Handles coordinate system transformations (WGS84 to Web Mercator)
- Optional buffer zones around places for nearby building detection

### 2. Fuzzy Name Matching
- **Exact Match Detection**: Perfect string matches get highest priority
- **Levenshtein Distance**: Character-level edit distance for typos and variations
- **Jaro-Winkler Similarity**: Optimized for name matching with transpositions
- **Substring Matching**: Handles abbreviated names and partial matches
- **Word Overlap**: Identifies common words between multi-word names

### 3. Distance-Based Ranking
- Exponential decay function favors closer buildings
- Combines spatial proximity with name similarity
- Configurable weighting between name matching and distance

### 4. Quality Classification
- **EXACT_NAME_MATCH**: Perfect name correspondence
- **HIGH_CONFIDENCE**: Strong similarity and close proximity
- **MEDIUM_CONFIDENCE**: Good match with some uncertainty
- **LOW_CONFIDENCE**: Weak match, manual review recommended
- **VERY_LOW_CONFIDENCE**: Poor match, likely incorrect
- **NO_BUILDING_MATCH**: No suitable building found

## Database Schema

### Input Tables

#### `overture_places`
```sql
- id: Unique place identifier
- names: JSON object with name variants
- categories: Place categories/types
- confidence: Data confidence score
- websites, socials, emails, phones: Contact information
- brand: Brand/chain information
- addresses: Address information
- sources: Data source attribution
- geometry: Point geometry (WGS84)
```

#### `overture_buildings`
```sql
- id: Unique building identifier
- names: JSON object with building names
- height: Building height
- num_floors: Number of floors
- level: Ground level information
- facade_color, facade_material: Facade properties
- roof_material, roof_shape, roof_direction, roof_color: Roof properties
- sources: Data source attribution
- geometry: Polygon geometry (WGS84)
```

### Output Table: `poi_table`

The final POI table combines all place information with matched building data and matching metadata:

```sql
-- Core identifiers
place_id, building_id

-- Complete place attributes (preserved from original)
place_names, place_categories, place_confidence, etc.

-- Complete building attributes (NULL if no match)
building_names, building_height, building_num_floors, etc.

-- Matching quality metrics
distance_meters                -- Distance between place and building centroid
name_similarity_score         -- Composite name matching score (0-1)
distance_score               -- Normalized distance score (0-1)
composite_match_score        -- Overall matching confidence (0-1)
match_quality               -- Categorical quality assessment
spatial_relationship        -- Spatial proximity classification
```

## Algorithm Details

### Step 1: Spatial Candidate Selection
```sql
-- Find all places within distance threshold of buildings
ST_DWithin(
    ST_Transform(place_geometry, 3857), 
    ST_Transform(building_geometry, 3857), 
    100  -- 100 meter threshold
)
```

### Step 2: Name Extraction and Cleaning
```sql
-- Extract primary names from JSON structure
COALESCE(
    names->>'primary',
    names->'common'->0->>'value',
    'Unknown'
)
```

### Step 3: Fuzzy Matching Calculation
```sql
-- Composite similarity score
name_similarity = (
    levenshtein_similarity * 0.3 +
    jaro_winkler_similarity * 0.3 +
    substring_match * 0.2 +
    exact_match * 0.2
)
```

### Step 4: Distance Normalization
```sql
-- Exponential decay distance scoring
distance_score = EXP(-distance_meters / 50.0)
```

### Step 5: Final Ranking
```sql
-- Combined matching score
composite_score = (name_similarity * 0.7 + distance_score * 0.3)

-- Ranking within each place
ROW_NUMBER() OVER (
    PARTITION BY place_id 
    ORDER BY composite_score DESC, distance_meters ASC
)
```

## Usage Instructions

### Prerequisites
- PostgreSQL with PostGIS extension (recommended)
- Or any spatial database with equivalent functions
- Overture Maps places and buildings data loaded

### Basic Execution
```sql
-- Run the main script
\i create_poi_table.sql

-- Check results
SELECT match_quality, COUNT(*) 
FROM poi_table 
GROUP BY match_quality;
```

### Configuration Options

#### Distance Threshold
```sql
-- Adjust the spatial search radius (in meters)
ST_DWithin(..., 100)  -- Change 100 to desired distance
```

#### Similarity Weights
```sql
-- Modify the composite scoring weights
name_similarity * 0.7 + distance_score * 0.3
-- Increase first weight to prioritize name matching
-- Increase second weight to prioritize proximity
```

#### Quality Thresholds
```sql
-- Adjust confidence level boundaries
WHEN composite_match_score >= 0.8 THEN 'HIGH_CONFIDENCE'
WHEN composite_match_score >= 0.6 THEN 'MEDIUM_CONFIDENCE'
-- Modify these values based on your quality requirements
```

### Alternative Implementations

#### For databases without advanced string functions:
Use `create_poi_table_alternative.sql` which provides:
- Basic substring matching
- Word overlap detection
- Length-based similarity
- Compatible with most SQL dialects

#### For very large datasets:
Consider partitioning strategies:
```sql
-- Partition by geographic regions
CREATE TABLE poi_table_partition_north AS
SELECT * FROM poi_table_creation_query
WHERE ST_Y(place_geometry) > 40.0;
```

## Performance Considerations

### Indexing Strategy
```sql
-- Spatial indexes (critical for performance)
CREATE INDEX idx_places_geom ON overture_places USING GIST(geometry);
CREATE INDEX idx_buildings_geom ON overture_buildings USING GIST(geometry);

-- Attribute indexes
CREATE INDEX idx_places_names ON overture_places USING GIN(names);
CREATE INDEX idx_buildings_names ON overture_buildings USING GIN(names);
```

### Memory and Processing
- Large datasets may require chunked processing
- Consider using `LIMIT` and `OFFSET` for batch processing
- Monitor memory usage during string similarity calculations

### Optimization Tips
1. **Pre-filter by categories**: Focus on relevant place types
2. **Geographic bounds**: Limit processing to specific regions
3. **Confidence thresholds**: Skip low-confidence places
4. **Parallel processing**: Use database partitioning features

## Quality Validation

### Automated Checks
```sql
-- Check for duplicate matches
SELECT building_id, COUNT(*) 
FROM poi_table 
WHERE building_id IS NOT NULL
GROUP BY building_id 
HAVING COUNT(*) > 1;

-- Validate distance calculations
SELECT place_id, distance_meters
FROM poi_table 
WHERE distance_meters > 1000  -- Flag suspicious distances
ORDER BY distance_meters DESC;

-- Review low-confidence matches
SELECT place_id, place_name_clean, building_name_clean, composite_match_score
FROM poi_table 
WHERE match_quality = 'LOW_CONFIDENCE'
ORDER BY composite_match_score ASC;
```

### Manual Review Recommendations
1. **Exact matches with high distance**: May indicate coordinate errors
2. **High similarity with very different categories**: Possible false positives
3. **Multiple high-confidence matches**: May need manual disambiguation

## Troubleshooting

### Common Issues

#### No matches found
- Check spatial reference systems (SRID)
- Verify data loading and table names
- Increase distance threshold
- Check for empty geometry fields

#### Poor matching quality
- Examine name formats in source data
- Adjust similarity weights
- Consider data cleaning preprocessing
- Review category filtering

#### Performance problems
- Add missing spatial indexes
- Reduce processing area
- Implement batch processing
- Consider hardware upgrades

### Debug Queries
```sql
-- Check data distribution
SELECT 
    COUNT(*) as total_places,
    COUNT(CASE WHEN ST_IsEmpty(geometry) THEN 1 END) as empty_geometries
FROM overture_places;

-- Sample name formats
SELECT names, COUNT(*) 
FROM overture_places 
GROUP BY names 
LIMIT 10;

-- Distance distribution
SELECT 
    CASE 
        WHEN distance_meters <= 10 THEN '0-10m'
        WHEN distance_meters <= 50 THEN '10-50m'
        WHEN distance_meters <= 100 THEN '50-100m'
        ELSE '>100m'
    END as distance_range,
    COUNT(*)
FROM poi_table 
WHERE building_id IS NOT NULL
GROUP BY distance_range;
```

## Future Enhancements

### Potential Improvements
1. **Machine Learning Integration**: Train models on validated matches
2. **Category-Aware Matching**: Weight similarity by place/building type compatibility
3. **Address Validation**: Incorporate address matching for additional confidence
4. **Temporal Matching**: Consider data freshness and update timestamps
5. **Multi-Language Support**: Handle names in different languages and scripts

### Advanced Features
- **Confidence Intervals**: Provide uncertainty ranges for matches
- **Alternative Matches**: Store multiple candidate matches per place
- **Batch Updates**: Incremental processing for data updates
- **API Integration**: Real-time matching for new places

## License and Attribution

This solution is designed for use with Overture Maps data. Please ensure compliance with:
- Overture Maps Foundation licensing terms
- Attribution requirements for derived datasets
- Local data protection and privacy regulations

## Support and Contributions

For issues, improvements, or questions:
1. Review the troubleshooting section
2. Check database-specific documentation
3. Validate input data quality
4. Consider posting issues with sample data and error messages