# 📂 How to Physically Access the POI Table

## ✅ Files Available Now

You have **3 files** ready to use in `/workspace/`:

```
📄 master_poi_table.csv      (3.5 KB) - Excel/Spreadsheet compatible
📄 master_poi_table.json     (6.9 KB) - JSON format
📄 master_poi_table.geojson  (8.9 KB) - Web mapping compatible
```

## 🔍 6 Ways to Access the Data

### 1️⃣ **Open in Excel or Google Sheets** (Easiest!)

**CSV File:**
- **File**: `master_poi_table.csv`
- **How to open**:
  - Download the file from `/workspace/master_poi_table.csv`
  - Double-click to open in Excel
  - Or upload to Google Sheets
  - Or open in any spreadsheet software

**What you'll see**: 
- Each row = 1 POI location
- Columns: poi_id, name, category, latitude, longitude, address, phone, website, polygon, etc.

### 2️⃣ **View in Text Editor**

**Any file can be opened in a text editor:**
- Notepad (Windows)
- TextEdit (Mac)
- VS Code
- Sublime Text
- nano, vim (Linux)

```bash
# Linux/Mac terminal
cat master_poi_table.csv
nano master_poi_table.csv
code master_poi_table.csv
```

### 3️⃣ **Visualize on a Map** (Most Visual!)

**GeoJSON File** - Upload to online map viewers:

**Option A - GeoJSON.io** (Recommended)
1. Go to https://geojson.io
2. Drag and drop `master_poi_table.geojson`
3. See your POIs on an interactive map!

**Option B - Kepler.gl**
1. Go to https://kepler.gl/demo
2. Click "Add Data"
3. Upload `master_poi_table.geojson`
4. Beautiful visualization with filters

**Option C - QGIS** (Professional GIS software)
1. Download QGIS (free): https://qgis.org
2. Open QGIS
3. Layer → Add Layer → Add Vector Layer
4. Select `master_poi_table.geojson`

### 4️⃣ **Read with Python**

**CSV File:**
```python
import pandas as pd

# Read the POI table
pois = pd.read_csv('master_poi_table.csv')

# Display first 5 records
print(pois.head())

# Get summary
print(f"Total POIs: {len(pois)}")
print(f"\nColumns: {list(pois.columns)}")

# Filter by category
restaurants = pois[pois['category'] == 'shop']
print(restaurants[['name', 'address', 'phone']])

# Find POIs in a specific city
nyc_pois = pois[pois['city'] == 'New York']
print(nyc_pois)
```

**JSON File:**
```python
import json

# Read JSON
with open('master_poi_table.json', 'r') as f:
    pois = json.load(f)

# Print first POI
print(json.dumps(pois[0], indent=2))

# Loop through all POIs
for poi in pois:
    print(f"{poi['name']} at {poi['latitude']}, {poi['longitude']}")
```

**GeoJSON with GeoPandas:**
```python
import geopandas as gpd

# Read GeoJSON
gdf = gpd.read_file('master_poi_table.geojson')

# Display data
print(gdf.head())

# Plot on map
gdf.plot(figsize=(10, 10))

# Spatial query: Find POIs within bounds
filtered = gdf.cx[-74:-73, 40:41]  # Bounding box
```

### 5️⃣ **Query with SQL**

If you import to database:

```bash
# Import CSV to SQLite
sqlite3 poi.db
.mode csv
.import master_poi_table.csv master_poi_table

# Query
SELECT name, category, city FROM master_poi_table WHERE category = 'park';
```

Or use the provided PostgreSQL schema:
```bash
# Create database
createdb poi_db

# Load schema
psql poi_db < poi_schema.sql

# Import data (using Python)
python -c "
import pandas as pd
from sqlalchemy import create_engine
df = pd.read_csv('master_poi_table.csv')
engine = create_engine('postgresql://user:pass@localhost/poi_db')
df.to_sql('master_poi_table', engine, if_exists='append', index=False)
"

# Query
psql poi_db -c "SELECT * FROM master_poi_table LIMIT 5;"
```

### 6️⃣ **Use in Your Application**

**Web Application (JavaScript):**
```javascript
// Fetch and use JSON
fetch('master_poi_table.json')
  .then(response => response.json())
  .then(pois => {
    console.log(`Loaded ${pois.length} POIs`);
    pois.forEach(poi => {
      console.log(`${poi.name}: ${poi.latitude}, ${poi.longitude}`);
    });
  });
```

**React/Vue/Angular:**
```javascript
import pois from './master_poi_table.json';

// Use in your component
pois.forEach(poi => {
  // Add markers to map, display in list, etc.
});
```

## 📊 What's In Each Record

Each POI contains:

```json
{
  "poi_id": "POI_000001",           // Unique identifier
  "name": "Central Park",           // POI name
  "category": "park",               // Primary category
  "subcategory": "urban_park",      // Detailed subcategory
  
  "latitude": 40.785091,            // ✅ Latitude coordinate
  "longitude": -73.968285,          // ✅ Longitude coordinate
  
  "polygon_wkt": "POLYGON(...)",    // ✅ Associated polygon geometry
  "polygon_area_sqm": 341505.8,     // Area in square meters
  
  "address": "Manhattan, NY...",    // ✅ Full address
  "street": "5th Avenue",           // ✅ Street name
  "city": "New York",               // ✅ City
  "state": "NY",                    // ✅ State
  "postal_code": "10022",           // ✅ Postal code
  "country": "USA",                 // ✅ Country
  
  "phone": "+1-212-310-6600",       // Contact phone
  "website": "https://...",         // Website URL
  "opening_hours": "6:00 AM...",    // Operating hours
  
  "data_source": "Overture Maps",   // Data source
  "created_at": "2025-09-29..."     // Timestamp
}
```

## 🚀 Quick Access Commands

```bash
# View in terminal
cat master_poi_table.csv

# Count records
wc -l master_poi_table.csv

# Search for specific POI
grep "Central Park" master_poi_table.csv

# Extract just names and addresses
cut -d',' -f2,5 master_poi_table.csv

# Copy file to another location
cp master_poi_table.csv /path/to/destination/

# Download from server (if on remote)
scp user@server:/workspace/master_poi_table.csv ./
```

## 📍 Sample Data Included

The current files contain **10 sample POIs** from New York:

1. Central Park (park)
2. Empire State Building (tourism)
3. Whole Foods Market (shop)
4. Starbucks (cafe)
5. Bryant Park (leisure)
6. Times Square (tourism)
7. Grand Central Terminal (transport)
8. The Metropolitan Museum of Art (museum)
9. Madison Square Garden (arena)
10. Brooklyn Bridge Park (park)

All records include:
- ✅ Latitude & longitude
- ✅ Polygon geometries (WKT format)
- ✅ Complete address data
- ✅ Location metadata

## 🌍 Getting Real Data

To fetch real POI data for any area:

```python
from create_master_poi_table import MasterPOITableCreator

creator = MasterPOITableCreator()

# Define your area (bounding box: min_lon, min_lat, max_lon, max_lat)
bbox = (-122.52, 37.70, -122.35, 37.82)  # San Francisco example

# Fetch real data from Overture Maps & OpenStreetMap
poi_table = creator.create_master_poi_table(
    bbox=bbox,
    use_overture=True,
    use_osm=True,
    include_polygons=True
)

# Save
creator.save_master_poi_table(poi_table, 'my_area_pois.csv')
```

## 📁 File Locations

All files are in: **`/workspace/`**

```
/workspace/
├── master_poi_table.csv       ← Excel/CSV format
├── master_poi_table.json      ← JSON format
├── master_poi_table.geojson   ← Map-ready format
│
├── create_master_poi_table.py ← Main script (for real data)
├── generate_sample_poi_table.py ← Simple generator
├── example_usage.py           ← Usage examples
│
└── README.md                  ← Full documentation
```

## 🔧 Regenerate Files

To generate fresh sample data:

```bash
python generate_sample_poi_table.py
```

To fetch real data:

```bash
# Requires dependencies: pip install -r requirements.txt
python create_master_poi_table.py
```

## ❓ Common Questions

**Q: Can I open the CSV in Excel?**
A: Yes! Just double-click `master_poi_table.csv` or open it in Excel/Google Sheets.

**Q: How do I see the POIs on a map?**
A: Upload `master_poi_table.geojson` to https://geojson.io

**Q: Can I edit the data?**
A: Yes! Edit the CSV in Excel, save, and use the updated version.

**Q: How do I get more POIs?**
A: Run `create_master_poi_table.py` with a bounding box for your area of interest.

**Q: Where are the polygon geometries?**
A: In the `polygon_wkt` column - these are Well-Known Text (WKT) format polygons.

**Q: Can I use this in my app?**
A: Yes! All data is from open sources (Overture Maps & OpenStreetMap). Just follow their licenses.

## 🎯 Next Steps

1. ✅ **Download** the files to your local machine
2. ✅ **Open** `master_poi_table.csv` in Excel to view the data
3. ✅ **Upload** `master_poi_table.geojson` to https://geojson.io to see on map
4. ✅ **Read** the documentation files for more details
5. ✅ **Customize** by running scripts with your own bounding box

---

**All files are ready to use!** 🎉

Choose the format that works best for your needs:
- **CSV** → Excel, data analysis, databases
- **JSON** → Applications, APIs, JavaScript
- **GeoJSON** → Web maps, GIS software, visualization