# Master POI Table from Open Source Data

A comprehensive solution for creating a master Points of Interest (POI) table using open-source geospatial data from **Overture Maps** and **OpenStreetMap**.

## 🎯 Features

- **Latitude & Longitude**: Precise coordinate data for each POI
- **Polygon Geometries**: Associated building footprints and area boundaries
- **Location Metadata**: Comprehensive name, category, and classification
- **Address Data**: Complete address information (street, city, state, postal code, country)
- **Contact Information**: Phone numbers, websites, and social media links
- **Multiple Formats**: Export to Parquet, CSV, GeoJSON, Shapefile, or PostgreSQL/PostGIS
- **Open Source Data**: Uses Overture Maps and OpenStreetMap data

## 📊 Data Sources

### 1. Overture Maps (Primary)
[Overture Maps](https://overturemaps.org/) is a collaborative initiative providing high-quality, open map data. It includes:
- 🏢 Places (POIs with detailed metadata)
- 🏗️ Buildings (footprint polygons)
- 📍 Addresses (structured address data)
- 🚗 Transportation networks

**Access Methods:**
- DuckDB queries directly from AWS S3
- Overture Maps Python SDK
- Direct download of GeoParquet files

### 2. OpenStreetMap (Secondary)
[OpenStreetMap](https://www.openstreetmap.org/) is a collaborative mapping project providing:
- 🗺️ POI data via Overpass API
- 🏘️ Rich tagging system for detailed attributes
- 🌍 Global coverage

## 🚀 Quick Start

### Installation

```bash
# Clone or download the repository
cd /workspace

# Install dependencies
pip install -r requirements.txt
```

### Basic Usage

```python
from create_master_poi_table import MasterPOITableCreator

# Initialize the creator
creator = MasterPOITableCreator(output_format='parquet')

# Create master POI table for a specific area
# Bounding box format: (min_lon, min_lat, max_lon, max_lat)
bbox = (-74.02, 40.70, -73.92, 40.80)  # New York City example

master_poi_table = creator.create_master_poi_table(
    bbox=bbox,
    use_overture=True,
    use_osm=True,
    include_polygons=True
)

# Save to file
creator.save_master_poi_table(master_poi_table, 'master_poi_table.parquet')
```

### Run the Example

```bash
python create_master_poi_table.py
```

## 📋 POI Table Schema

| Field | Type | Description |
|-------|------|-------------|
| `poi_id` | String | Unique identifier for each POI |
| `name` | String | Name of the location |
| `category` | String | Primary category (e.g., restaurant, shop, park) |
| `subcategory` | String | Detailed subcategory (e.g., italian_restaurant) |
| `address` | String | Full address string |
| `street` | String | Street name and number |
| `city` | String | City name |
| `state` | String | State/region |
| `postal_code` | String | ZIP/postal code |
| `country` | String | Country name |
| `latitude` | Float | Latitude (WGS84) |
| `longitude` | Float | Longitude (WGS84) |
| `geometry` | Geometry | Point geometry (PostGIS) |
| `building_polygon` | Geometry | Associated building polygon |
| `polygon_area_sqm` | Float | Area in square meters |
| `phone` | String | Phone number |
| `website` | String | Website URL |
| `opening_hours` | String | Operating hours |
| `data_source` | String | Source (Overture Maps, OpenStreetMap) |
| `created_at` | Timestamp | Record creation timestamp |

## 💾 Export Formats

### 1. Parquet (Recommended)
```python
creator.save_master_poi_table(poi_table, 'pois.parquet')
```
- Efficient columnar storage
- Preserves geometry data
- Fast read/write performance

### 2. CSV
```python
creator.save_master_poi_table(poi_table, 'pois.csv')
```
- Universal compatibility
- Coordinates as separate columns
- No geometry objects

### 3. GeoJSON
```python
creator.save_master_poi_table(poi_table, 'pois.geojson')
```
- Web mapping compatible
- Includes geometry data
- Human-readable

### 4. GeoPackage
```python
creator.save_master_poi_table(poi_table, 'pois.gpkg')
```
- OGC standard format
- SQLite-based
- Desktop GIS compatible

### 5. PostgreSQL/PostGIS
```python
creator.export_to_database(
    poi_table,
    'postgresql://user:password@localhost:5432/poi_db',
    table_name='master_poi_table'
)
```

## 🗄️ Database Setup (PostgreSQL/PostGIS)

```bash
# Install PostgreSQL and PostGIS
sudo apt-get install postgresql postgis

# Create database
createdb poi_database

# Run schema creation
psql poi_database < poi_schema.sql
```

## 📍 Example Queries

### Python (GeoPandas)
```python
import geopandas as gpd

# Read POI table
pois = gpd.read_parquet('master_poi_table.parquet')

# Filter by category
restaurants = pois[pois['category'] == 'restaurant']

# Filter by location (within bounds)
nyc_pois = pois[
    (pois['longitude'] >= -74.02) & (pois['longitude'] <= -73.92) &
    (pois['latitude'] >= 40.70) & (pois['latitude'] <= 40.80)
]

# Spatial query: POIs within 1km of a point
from shapely.geometry import Point
center = Point(-73.985428, 40.748817)  # Empire State Building
nearby_pois = pois[pois.geometry.distance(center) < 0.01]  # ~1km
```

### SQL (PostgreSQL/PostGIS)
```sql
-- Find POIs within 1km of a point
SELECT poi_id, name, category, 
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

-- Count POIs by category and city
SELECT category, city, COUNT(*) as count
FROM master_poi_table
GROUP BY category, city
ORDER BY count DESC;

-- Find POIs intersecting with a polygon
SELECT poi_id, name
FROM master_poi_table
WHERE ST_Intersects(
    geometry,
    ST_GeomFromText('POLYGON((-74.02 40.70, -73.92 40.70, -73.92 40.80, -74.02 40.80, -74.02 40.70))', 4326)
);
```

## 🔧 Advanced Configuration

### Custom Bounding Box
```python
# Define your area of interest
# Format: (min_longitude, min_latitude, max_longitude, max_latitude)
custom_bbox = (-122.5, 37.7, -122.3, 37.9)  # San Francisco

pois = creator.create_master_poi_table(bbox=custom_bbox)
```

### Filter by POI Categories
```python
# OpenStreetMap categories
osm_categories = ['amenity', 'shop', 'tourism', 'leisure', 'office']

osm_data = creator.fetch_osm_poi_data(
    bbox=(37.7, -122.5, 37.9, -122.3),
    poi_types=osm_categories
)
```

### Using DuckDB for Overture Maps
```python
import duckdb

# Query Overture Maps data directly from S3
con = duckdb.connect()
query = """
INSTALL spatial;
LOAD spatial;
INSTALL httpfs;
LOAD httpfs;
SET s3_region='us-west-2';

SELECT 
    id,
    JSON_EXTRACT_STRING(names, '$.primary') as name,
    ST_X(ST_GeomFromWKB(geometry)) as longitude,
    ST_Y(ST_GeomFromWKB(geometry)) as latitude
FROM read_parquet('s3://overturemaps-us-west-2/release/2024-11-13.0/theme=places/type=place/*')
LIMIT 1000;
"""
result = con.execute(query).fetchdf()
```

## 📦 Data Processing Pipeline

```
┌─────────────────────┐
│  Overture Maps      │
│  (AWS S3)           │
└──────────┬──────────┘
           │
           ├──────────> DuckDB Query
           │
           v
┌─────────────────────┐     ┌─────────────────────┐
│  OpenStreetMap      │     │   Building          │
│  (Overpass API)     │────>│   Polygons          │
└──────────┬──────────┘     └──────────┬──────────┘
           │                           │
           v                           v
┌──────────────────────────────────────────────────┐
│         Master POI Table (GeoDataFrame)          │
│  - Coordinates (lat, lon)                        │
│  - Polygons (building footprints)                │
│  - Metadata (name, category, address)            │
└──────────────────────────────────────────────────┘
           │
           ├──────> Parquet
           ├──────> CSV
           ├──────> GeoJSON
           └──────> PostgreSQL/PostGIS
```

## 🌍 Supported Regions

- ✅ **Global Coverage**: Both Overture Maps and OpenStreetMap provide worldwide data
- 🎯 **Best Quality**: Urban areas in North America, Europe, and Asia
- 📈 **Continuous Updates**: Regular data releases from both sources

## 🔍 Data Quality

### Overture Maps
- **Confidence Score**: Each POI includes a confidence metric
- **Source Attribution**: Multiple source references
- **Validation**: Community-reviewed and validated
- **Update Frequency**: Quarterly releases

### OpenStreetMap
- **Community Verified**: Millions of contributors
- **Rich Attributes**: Detailed tagging system
- **Real-time Updates**: Near real-time data availability
- **Quality Tools**: Built-in validation mechanisms

## 🤝 Contributing

To improve the POI data quality:

1. **Overture Maps**: Contribute to upstream sources (OSM, municipal data)
2. **OpenStreetMap**: Edit directly at [openstreetmap.org](https://www.openstreetmap.org)
3. **This Project**: Submit pull requests for code improvements

## 📚 Resources

- [Overture Maps Documentation](https://docs.overturemaps.org/)
- [OpenStreetMap Wiki](https://wiki.openstreetmap.org/)
- [GeoPandas Documentation](https://geopandas.org/)
- [DuckDB Spatial Extension](https://duckdb.org/docs/extensions/spatial.html)
- [PostGIS Documentation](https://postgis.net/documentation/)

## 📝 License

This project uses open-source data:
- **Overture Maps**: [CDLA Permissive 2.0](https://overturemaps.org/license/)
- **OpenStreetMap**: [ODbL (Open Database License)](https://www.openstreetmap.org/copyright)

## ⚠️ Notes

1. **Rate Limits**: OpenStreetMap Overpass API has usage limits. For large extracts, download regional files from [Geofabrik](https://download.geofabrik.de/).

2. **Memory**: Processing large areas may require significant RAM. Consider:
   - Processing in smaller chunks
   - Using DuckDB for out-of-core processing
   - Using cloud compute resources

3. **Data Currency**: POI data changes frequently. Re-run extraction periodically to keep data current.

4. **Coordinate System**: All data uses WGS84 (EPSG:4326) for consistency.

## 🎯 Next Steps

1. Run the script to generate sample data
2. Customize for your area of interest
3. Set up PostgreSQL/PostGIS for production use
4. Integrate with your application or analysis pipeline
5. Schedule regular updates to maintain data currency

## 💡 Use Cases

- 🗺️ **Mapping Applications**: Base layer for web/mobile maps
- 📊 **Business Intelligence**: Market analysis and site selection
- 🚗 **Navigation Systems**: POI database for routing
- 🏢 **Real Estate**: Property analysis and valuation
- 📱 **Location Services**: Recommendation engines
- 🔬 **Research**: Urban planning and spatial analysis

---

**Created with open source data from Overture Maps and OpenStreetMap** 🌍