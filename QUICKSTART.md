# Quick Start Guide - Master POI Table

## 🎯 Overview

This project creates a comprehensive master POI (Points of Interest) table using **open-source data** from:
- **Overture Maps** - High-quality, open map data
- **OpenStreetMap** - Community-driven mapping data

## 📦 What's Included

### Files Created:
1. **`create_master_poi_table.py`** - Main Python script to fetch and process POI data
2. **`requirements.txt`** - Python dependencies
3. **`poi_schema.sql`** - PostgreSQL/PostGIS database schema
4. **`example_usage.py`** - 8 detailed usage examples
5. **`README.md`** - Comprehensive documentation
6. **`setup.sh`** - Automated setup script

## 🚀 Quick Installation

### Option 1: Using Setup Script (Linux/Mac)
```bash
chmod +x setup.sh
./setup.sh
```

### Option 2: Manual Setup
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Option 3: Using System Python with --break-system-packages
```bash
pip install -r requirements.txt --break-system-packages
```

## 🏃 Running the Script

### Basic Usage (Sample Data)
```bash
python create_master_poi_table.py
```

This will:
- Generate sample POI data for demonstration
- Create files: `master_poi_table.parquet`, `master_poi_table.csv`, `master_poi_table.geojson`
- Display POI information and schema

### Custom Area Example
```python
from create_master_poi_table import MasterPOITableCreator

creator = MasterPOITableCreator()

# New York City bounding box
bbox = (-74.02, 40.70, -73.92, 40.80)

poi_table = creator.create_master_poi_table(
    bbox=bbox,
    use_overture=True,
    use_osm=True,
    include_polygons=True
)

creator.save_master_poi_table(poi_table, 'nyc_pois.parquet')
```

## 📊 Output Data Structure

Each POI record includes:

```
POI Record:
├── poi_id: "POI_000001"
├── name: "Central Park"
├── category: "park"
├── subcategory: "urban_park"
├── address: "Manhattan, New York, NY 10022"
├── street: "5th Avenue"
├── city: "New York"
├── state: "NY"
├── postal_code: "10022"
├── country: "USA"
├── latitude: 40.785091
├── longitude: -73.968285
├── geometry: POINT(-73.968285 40.785091)
├── building_polygon: POLYGON(...)
├── polygon_area_sqm: 1234.56
├── phone: "+1-212-310-6600"
├── website: "https://..."
└── data_source: "Overture Maps"
```

## 🗄️ Database Setup (PostgreSQL/PostGIS)

### 1. Install PostgreSQL and PostGIS
```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgis

# macOS
brew install postgresql postgis

# Windows - Download from postgresql.org
```

### 2. Create Database
```bash
createdb poi_database
```

### 3. Apply Schema
```bash
psql poi_database < poi_schema.sql
```

### 4. Import Data
```python
from create_master_poi_table import MasterPOITableCreator

creator = MasterPOITableCreator()
poi_table = creator.create_master_poi_table()

creator.export_to_database(
    poi_table,
    'postgresql://username:password@localhost:5432/poi_database',
    table_name='master_poi_table'
)
```

## 🔍 Example Queries

### Python (Pandas/GeoPandas)
```python
import geopandas as gpd

# Read POI table
pois = gpd.read_parquet('master_poi_table.parquet')

# Filter by category
restaurants = pois[pois['category'] == 'restaurant']

# Filter by location
nyc_pois = pois[
    (pois['longitude'] >= -74.02) & (pois['longitude'] <= -73.92) &
    (pois['latitude'] >= 40.70) & (pois['latitude'] <= 40.80)
]

# Find POIs near a point
from shapely.geometry import Point
target = Point(-73.985428, 40.748817)
nearby = pois[pois.geometry.distance(target) < 0.01]
```

### SQL (PostgreSQL)
```sql
-- Find POIs within 1km of a point
SELECT name, category, 
       ST_Distance(geometry::geography, 
                   ST_SetSRID(ST_MakePoint(-73.985428, 40.748817), 4326)::geography) 
       as distance_meters
FROM master_poi_table
WHERE ST_DWithin(
    geometry::geography,
    ST_SetSRID(ST_MakePoint(-73.985428, 40.748817), 4326)::geography,
    1000
)
ORDER BY distance_meters;

-- Count POIs by category
SELECT category, COUNT(*) as count
FROM master_poi_table
GROUP BY category
ORDER BY count DESC;
```

## 🌍 Data Sources

### Overture Maps
- **Website**: https://overturemaps.org/
- **License**: CDLA Permissive 2.0
- **Access**: AWS S3 (public data)
- **Format**: GeoParquet
- **Coverage**: Global
- **Update Frequency**: Quarterly

**How to Access Real Overture Data:**
```python
import duckdb

con = duckdb.connect()
con.execute("""
    INSTALL spatial; LOAD spatial;
    INSTALL httpfs; LOAD httpfs;
    SET s3_region='us-west-2';
""")

# Query places data
df = con.execute("""
    SELECT 
        id,
        JSON_EXTRACT_STRING(names, '$.primary') as name,
        ST_X(ST_GeomFromWKB(geometry)) as longitude,
        ST_Y(ST_GeomFromWKB(geometry)) as latitude
    FROM read_parquet('s3://overturemaps-us-west-2/release/2024-11-13.0/theme=places/type=place/*')
    LIMIT 1000
""").fetchdf()
```

### OpenStreetMap
- **Website**: https://www.openstreetmap.org/
- **License**: ODbL (Open Database License)
- **Access**: Overpass API
- **Coverage**: Global
- **Update Frequency**: Real-time

**How to Access Real OSM Data:**
```python
import requests

overpass_url = "http://overpass-api.de/api/interpreter"
query = """
[out:json];
(
  node["amenity"="restaurant"](40.70,-74.02,40.80,-73.92);
);
out center;
"""

response = requests.post(overpass_url, data={'data': query})
data = response.json()
```

## 📈 Scaling to Production

### For Large Areas:
1. **Use DuckDB** - Query Overture data directly from S3
2. **Process in Chunks** - Break large areas into smaller bounding boxes
3. **Use Cloud Compute** - AWS EC2, Google Cloud, or Azure
4. **Optimize Storage** - Use Parquet for efficient columnar storage

### For Regular Updates:
1. **Cron Jobs** - Schedule regular data refreshes
2. **Change Detection** - Track and merge only updated POIs
3. **Version Control** - Maintain historical snapshots

### Performance Tips:
```python
# Process in parallel
from multiprocessing import Pool

def process_bbox(bbox):
    creator = MasterPOITableCreator()
    return creator.create_master_poi_table(bbox=bbox)

bboxes = [...]  # List of bounding boxes
with Pool(4) as p:
    results = p.map(process_bbox, bboxes)
```

## 🎓 Advanced Examples

See `example_usage.py` for 8 comprehensive examples:
1. Basic usage
2. Specific geographic area
3. Filter and analyze
4. Spatial queries
5. Export to database
6. Custom processing
7. Map visualization
8. Bulk processing

Run all examples:
```bash
python example_usage.py
```

## ❓ Troubleshooting

### Import Errors
```bash
pip install geopandas pandas shapely requests pyarrow
```

### Memory Issues
- Process smaller areas
- Use DuckDB for out-of-core processing
- Increase swap space

### API Rate Limits (OpenStreetMap)
- Use Geofabrik extracts for large areas
- Implement request delays
- Consider local OSM database

### Database Connection Issues
```bash
# Check PostgreSQL is running
sudo service postgresql status

# Test connection
psql -U username -d poi_database -c "SELECT version();"
```

## 📝 Next Steps

1. ✅ Review the generated sample data
2. ✅ Customize for your area of interest
3. ✅ Set up PostgreSQL/PostGIS (optional)
4. ✅ Integrate with your application
5. ✅ Schedule regular updates

## 🤝 Support

- **Overture Maps**: https://docs.overturemaps.org/
- **OpenStreetMap**: https://wiki.openstreetmap.org/
- **GeoPandas**: https://geopandas.org/
- **PostGIS**: https://postgis.net/

## 📜 License

Data licenses:
- Overture Maps: CDLA Permissive 2.0
- OpenStreetMap: ODbL

This code: Open source (use as you wish!)

---

**Ready to create your master POI table!** 🎉