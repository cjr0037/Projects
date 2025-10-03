# Quick Start Guide

Get your POI table up and running in 3 steps!

## Step 1: Verify Your Data

Run these checks to ensure your Overture Maps tables are ready:

```sql
-- Check places table
SELECT COUNT(*) FROM overture_maps_places;

-- Check buildings table  
SELECT COUNT(*) FROM overture_maps_buildings;

-- Verify geometry types (should be GEOGRAPHY)
SELECT ST_GEOMETRYTYPE(geometry) FROM overture_maps_places LIMIT 1;
SELECT ST_GEOMETRYTYPE(geometry) FROM overture_maps_buildings LIMIT 1;
```

**Expected Results:**
- Both tables should have data
- Places should have POINT geometries
- Buildings should have POLYGON or MULTIPOLYGON geometries

## Step 2: Adjust Configuration (Optional)

Open `create_poi_table.sql` and adjust these parameters if needed:

```sql
-- Line ~30: Distance threshold in meters
ST_DWITHIN(p.geometry, b.geometry, 50) -- Change 50 to your preferred distance

-- Line ~95-102: Scoring weights
(name_similarity_score * 0.6) +        -- 60% for name matching
(distance_proximity * 0.4) +           -- 40% for distance
(containment_bonus)                    -- 20 points bonus
```

**Recommended Starting Values:**
- **Urban areas:** 25-50 meter distance threshold
- **Suburban areas:** 50-100 meter distance threshold  
- **Rural areas:** 100+ meter distance threshold

## Step 3: Run the Script

Execute the main script in your Snowflake worksheet:

```sql
-- Copy and paste the entire content of create_poi_table.sql
-- Or use Snowflake's execute file feature
```

**Expected Runtime:**
- Small dataset (<10K places): 1-5 minutes
- Medium dataset (<100K places): 5-15 minutes  
- Large dataset (>100K places): 15+ minutes

## Step 4: Review Results

Check the automatically generated summary:

```sql
-- Summary statistics (shown at end of script)
-- Look for:
-- - Total POIs
-- - POIs with building match
-- - POIs contained in building
-- - POIs with high name similarity

-- View sample results
SELECT 
    place_name,
    building_name,
    ROUND(composite_score, 1) AS score
FROM poi_table
ORDER BY composite_score DESC
LIMIT 20;
```

## Common Issues & Quick Fixes

### Issue: Very few matches (<50%)

**Fix 1:** Increase distance threshold
```sql
-- Change from 50 to 100 meters
ST_DWITHIN(p.geometry, b.geometry, 100)
```

**Fix 2:** Lower name similarity requirement
```sql
-- Line ~115, change from 70 to 50
name_similarity_score >= 50
```

### Issue: Many poor quality matches

**Fix 1:** Increase name similarity requirement  
```sql
-- Line ~115, change from 70 to 80
name_similarity_score >= 80
```

**Fix 2:** Decrease distance threshold
```sql
-- Change from 50 to 25 meters
ST_DWITHIN(p.geometry, b.geometry, 25)
```

**Fix 3:** Use strict containment approach
```sql
-- See poi_matching_config.sql for alternative strategies
```

### Issue: Script runs too slowly

**Fix 1:** Process in batches by region
```sql
-- Add WHERE clause with bounding box
WHERE ST_WITHIN(p.geometry, 
    ST_MAKEPOLYGON('LINESTRING(-122.5 37.7, -122.5 37.8, -122.4 37.8, -122.4 37.7, -122.5 37.7)')
)
```

**Fix 2:** Increase warehouse size
```sql
-- Use larger warehouse temporarily
USE WAREHOUSE large_warehouse;
```

**Fix 3:** Test with sample first
```sql
-- Test logic on small sample
CREATE TEMP TABLE sample_places AS 
SELECT * FROM overture_maps_places LIMIT 5000;
```

## Understanding the Results

### Composite Score Interpretation

- **90-100:** Excellent match (name matches, spatially contained)
- **75-89:** Good match (strong name similarity or very close distance)
- **60-74:** Fair match (moderate name similarity with reasonable distance)
- **40-59:** Poor match (weak name match or far distance)
- **<40:** Very poor match (consider excluding)

### Key Metrics to Monitor

```sql
SELECT 
    COUNT(*) AS total,
    ROUND(AVG(composite_score), 1) AS avg_score,
    ROUND(AVG(name_similarity_score), 1) AS avg_name_sim,
    ROUND(AVG(distance_meters), 1) AS avg_distance,
    SUM(CASE WHEN is_contained THEN 1 ELSE 0 END) AS num_contained
FROM poi_table
WHERE building_id IS NOT NULL;
```

**Good Results Indicators:**
- Average composite score > 75
- Average name similarity > 60
- Average distance < 15 meters
- >30% of POIs contained in buildings

## Next Steps

### Option 1: Use Default Configuration
If results look good (>70% match rate, avg score >75), you're done!

### Option 2: Fine-tune Parameters
- Review `poi_matching_config.sql` for alternative strategies
- Run quality checks from `example_queries.sql`
- Adjust weights and thresholds based on your data

### Option 3: Custom Approach
- Use one of the alternative strategies (strict containment, name-priority, nearest)
- Create your own scoring formula
- Filter results by specific categories or regions

## Validation Queries

Run these to ensure quality:

```sql
-- 1. Check for duplicates (should return 0)
SELECT place_id, COUNT(*) 
FROM poi_table 
GROUP BY place_id 
HAVING COUNT(*) > 1;

-- 2. Review match quality distribution
SELECT 
    CASE 
        WHEN composite_score >= 90 THEN 'Excellent'
        WHEN composite_score >= 75 THEN 'Good'
        WHEN composite_score >= 60 THEN 'Fair'
        ELSE 'Poor'
    END AS quality,
    COUNT(*) AS count
FROM poi_table
WHERE building_id IS NOT NULL
GROUP BY quality;

-- 3. Find suspicious matches for manual review
SELECT * FROM poi_table
WHERE building_id IS NOT NULL
  AND composite_score < 50
ORDER BY composite_score
LIMIT 20;
```

## Getting Help

1. **Check the README.md** for detailed documentation
2. **Run example_queries.sql** for diagnostic queries  
3. **Review poi_matching_config.sql** for alternative approaches
4. **Examine your data** - look at actual names and geometries to understand mismatches

## Example Use Cases

### Find all restaurants with building info
```sql
SELECT place_name, building_name, addresses
FROM poi_table
WHERE categories:primary::STRING = 'restaurant'
  AND building_id IS NOT NULL;
```

### Export high-quality matches
```sql
SELECT 
    place_id,
    place_name,
    building_id,
    ST_ASGEOJSON(building_geometry) AS geojson
FROM poi_table
WHERE composite_score >= 85;
```

### Analyze POI density by building
```sql
SELECT 
    building_id,
    building_name,
    COUNT(*) AS num_pois
FROM poi_table
WHERE building_id IS NOT NULL
GROUP BY building_id, building_name
HAVING COUNT(*) >= 3
ORDER BY num_pois DESC;
```

---

**Ready to start?** Open `create_poi_table.sql` and run it in Snowflake! 🚀
