# Master POI Table - Architecture & Data Flow

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES (Open Source)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────┐        ┌────────────────────────────┐    │
│  │   OVERTURE MAPS         │        │    OPENSTREETMAP (OSM)     │    │
│  │   ─────────────         │        │    ───────────────────     │    │
│  │  • AWS S3 Storage       │        │  • Overpass API            │    │
│  │  • GeoParquet Format    │        │  • Global Coverage         │    │
│  │  • Places Theme         │        │  • Rich Tagging            │    │
│  │  • Buildings Theme      │        │  • Real-time Updates       │    │
│  │  • Addresses Theme      │        │  • Community Data          │    │
│  │  • High Quality         │        │  • HTTP/JSON API           │    │
│  └──────────┬──────────────┘        └──────────┬─────────────────┘    │
│             │                                   │                       │
└─────────────┼───────────────────────────────────┼───────────────────────┘
              │                                   │
              ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        DATA EXTRACTION LAYER                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  create_master_poi_table.py                                      │  │
│  │  ──────────────────────────────────────────────────────────────  │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────────┐ │  │
│  │  │  MasterPOITableCreator Class                               │ │  │
│  │  │  ────────────────────────────────────────────────────────  │ │  │
│  │  │                                                            │ │  │
│  │  │  ┌──────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  fetch_overture_poi_data()                           │ │ │  │
│  │  │  │  • Query Overture via DuckDB                         │ │ │  │
│  │  │  │  • Extract: name, category, coordinates             │ │ │  │
│  │  │  │  • Extract: address, phone, website                 │ │ │  │
│  │  │  │  • Filter by bounding box                           │ │ │  │
│  │  │  └──────────────────────────────────────────────────────┘ │ │  │
│  │  │                                                            │ │  │
│  │  │  ┌──────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  fetch_osm_poi_data()                                │ │ │  │
│  │  │  │  • Query OSM Overpass API                            │ │ │  │
│  │  │  │  • Parse nodes, ways, relations                      │ │ │  │
│  │  │  │  • Extract tags and attributes                       │ │ │  │
│  │  │  │  • Convert to standard format                        │ │ │  │
│  │  │  └──────────────────────────────────────────────────────┘ │ │  │
│  │  │                                                            │ │  │
│  │  │  ┌──────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  fetch_building_polygons()                           │ │ │  │
│  │  │  │  • Match POIs to building footprints                 │ │ │  │
│  │  │  │  • Extract polygon geometries                        │ │ │  │
│  │  │  │  • Calculate areas                                   │ │ │  │
│  │  │  └──────────────────────────────────────────────────────┘ │ │  │
│  │  │                                                            │ │  │
│  │  │  ┌──────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  create_master_poi_table()                           │ │ │  │
│  │  │  │  • Combine all data sources                          │ │ │  │
│  │  │  │  • Deduplicate and merge                             │ │ │  │
│  │  │  │  • Standardize schema                                │ │ │  │
│  │  │  │  • Generate unique IDs                               │ │ │  │
│  │  │  └──────────────────────────────────────────────────────┘ │ │  │
│  │  └────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     DATA PROCESSING & ENRICHMENT                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │  Coordinate    │  │  Polygon        │  │  Address               │  │
│  │  Extraction    │  │  Association    │  │  Parsing               │  │
│  │  ──────────    │  │  ────────────   │  │  ──────────            │  │
│  │  • Latitude    │  │  • Building     │  │  • Street              │  │
│  │  • Longitude   │  │  • Footprint    │  │  • City                │  │
│  │  • WGS84       │  │  • Area (sqm)   │  │  • State               │  │
│  │  • Validation  │  │  • WKT format   │  │  • Postal Code         │  │
│  └────────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                         │
│  ┌────────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │  Metadata      │  │  Category       │  │  Contact Info          │  │
│  │  Extraction    │  │  Mapping        │  │  Extraction            │  │
│  │  ──────────    │  │  ─────────      │  │  ──────────            │  │
│  │  • POI Name    │  │  • Primary Cat  │  │  • Phone               │  │
│  │  • Description │  │  • Subcategory  │  │  • Website             │  │
│  │  • Tags        │  │  • Taxonomy     │  │  • Hours               │  │
│  └────────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         MASTER POI TABLE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  GeoPandas DataFrame / GeoDataFrame                                     │
│  ───────────────────────────────────────────────────────────────────   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Column Structure:                                               │  │
│  │  ────────────────                                                │  │
│  │                                                                  │  │
│  │  poi_id          │ name               │ category                │  │
│  │  latitude        │ longitude          │ geometry (POINT)        │  │
│  │  building_polygon│ polygon_area_sqm   │ address                 │  │
│  │  street          │ city               │ state                   │  │
│  │  postal_code     │ country            │ phone                   │  │
│  │  website         │ opening_hours      │ data_source             │  │
│  │  subcategory     │ created_at         │ [custom fields...]      │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          EXPORT OPTIONS                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────┐   │
│  │  Parquet   │  │    CSV     │  │  GeoJSON   │  │  GeoPackage    │   │
│  │  ────────  │  │    ───     │  │  ────────  │  │  ───────────   │   │
│  │  • Fast    │  │  • Simple  │  │  • Web map │  │  • OGC std     │   │
│  │  • Compact │  │  • Excel   │  │  • JSON    │  │  • SQLite      │   │
│  │  • Columnar│  │  • Import  │  │  • Geom    │  │  • Desktop GIS │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────────┘   │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  PostgreSQL / PostGIS                                          │    │
│  │  ─────────────────────                                         │    │
│  │  • Spatial database                                            │    │
│  │  • Spatial indices (GIST)                                      │    │
│  │  • Full-text search                                            │    │
│  │  • Materialized views                                          │    │
│  │  • Production-ready                                            │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         USE CASES / APPLICATIONS                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐    │
│  │  Business       │  │  Navigation      │  │  Real Estate       │    │
│  │  Intelligence   │  │  & Maps          │  │  Analysis          │    │
│  └─────────────────┘  └──────────────────┘  └────────────────────┘    │
│                                                                         │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐    │
│  │  Urban          │  │  Research &      │  │  Location-based    │    │
│  │  Planning       │  │  Analysis        │  │  Services          │    │
│  └─────────────────┘  └──────────────────┘  └────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📋 Data Schema

### POI Table Structure

```
master_poi_table
├── Identifiers
│   └── poi_id (VARCHAR PRIMARY KEY)
│
├── Location Coordinates
│   ├── latitude (DECIMAL)
│   ├── longitude (DECIMAL)
│   └── geometry (GEOMETRY(Point, 4326))
│
├── Polygons
│   ├── building_polygon (GEOMETRY(Polygon, 4326))
│   └── polygon_area_sqm (DECIMAL)
│
├── Metadata
│   ├── name (VARCHAR)
│   ├── category (VARCHAR)
│   └── subcategory (VARCHAR)
│
├── Address Components
│   ├── address (TEXT)
│   ├── street (VARCHAR)
│   ├── city (VARCHAR)
│   ├── state (VARCHAR)
│   ├── postal_code (VARCHAR)
│   └── country (VARCHAR)
│
├── Contact Information
│   ├── phone (VARCHAR)
│   ├── website (VARCHAR)
│   └── opening_hours (TEXT)
│
└── Data Provenance
    ├── data_source (VARCHAR)
    └── created_at (TIMESTAMP)
```

## 🔄 Data Flow Diagram

```
START
  │
  ├─→ Define Area (Bounding Box)
  │
  ├─→ Query Overture Maps
  │     │
  │     ├─→ Places (POI points)
  │     ├─→ Buildings (Polygons)
  │     └─→ Addresses (Structured)
  │
  ├─→ Query OpenStreetMap
  │     │
  │     ├─→ Nodes (POI points)
  │     ├─→ Ways (Lines/Polygons)
  │     └─→ Relations (Complex features)
  │
  ├─→ Data Processing
  │     │
  │     ├─→ Parse & Extract
  │     ├─→ Standardize Schema
  │     ├─→ Merge Sources
  │     ├─→ Deduplicate
  │     └─→ Validate
  │
  ├─→ Enrichment
  │     │
  │     ├─→ Associate Polygons
  │     ├─→ Calculate Areas
  │     └─→ Add Metadata
  │
  ├─→ Master POI Table (GeoDataFrame)
  │
  └─→ Export
        │
        ├─→ Parquet File
        ├─→ CSV File
        ├─→ GeoJSON File
        ├─→ GeoPackage File
        └─→ PostgreSQL Database
        
END
```

## 🛠️ Technology Stack

```
┌───────────────────────────────────────────────────┐
│            APPLICATION LAYER                      │
│  ┌─────────────────────────────────────────────┐ │
│  │  create_master_poi_table.py                 │ │
│  │  example_usage.py                           │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────┬─────────────────────────────────┘
                  │
┌─────────────────┴─────────────────────────────────┐
│         GEOSPATIAL LIBRARIES                      │
│  ┌──────────────┐  ┌─────────────────────────┐   │
│  │  GeoPandas   │  │  Shapely                │   │
│  │  • GeoDF     │  │  • Point/Polygon        │   │
│  │  • Spatial   │  │  • Geometric ops        │   │
│  └──────────────┘  └─────────────────────────┘   │
└─────────────────┬─────────────────────────────────┘
                  │
┌─────────────────┴─────────────────────────────────┐
│         DATA PROCESSING LIBRARIES                 │
│  ┌──────────────┐  ┌─────────────────────────┐   │
│  │  Pandas      │  │  NumPy                  │   │
│  │  • DataFrame │  │  • Arrays               │   │
│  │  • Analysis  │  │  • Math ops             │   │
│  └──────────────┘  └─────────────────────────┘   │
└─────────────────┬─────────────────────────────────┘
                  │
┌─────────────────┴─────────────────────────────────┐
│         DATA ACCESS LIBRARIES                     │
│  ┌──────────────┐  ┌─────────────────────────┐   │
│  │  DuckDB      │  │  Requests               │   │
│  │  • S3 query  │  │  • HTTP API             │   │
│  │  • Parquet   │  │  • REST calls           │   │
│  └──────────────┘  └─────────────────────────┘   │
└─────────────────┬─────────────────────────────────┘
                  │
┌─────────────────┴─────────────────────────────────┐
│         STORAGE & DATABASE                        │
│  ┌──────────────┐  ┌─────────────────────────┐   │
│  │  PostgreSQL  │  │  File Formats           │   │
│  │  • PostGIS   │  │  • Parquet              │   │
│  │  • Spatial   │  │  • GeoJSON              │   │
│  └──────────────┘  └─────────────────────────┘   │
└───────────────────────────────────────────────────┘
```

## 🔍 Query Architecture

### Spatial Queries Supported

```
┌─────────────────────────────────────────────────┐
│           SPATIAL QUERY TYPES                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  1. Distance Queries                            │
│     • Find POIs within radius                   │
│     • Nearest N POIs                            │
│     • K-nearest neighbors                       │
│                                                 │
│  2. Intersection Queries                        │
│     • POIs within polygon                       │
│     • POIs intersecting area                    │
│     • Boundary analysis                         │
│                                                 │
│  3. Buffer Queries                              │
│     • Create buffer zones                       │
│     • Find POIs in buffer                       │
│     • Trade area analysis                       │
│                                                 │
│  4. Containment Queries                         │
│     • Point in polygon                          │
│     • Polygon contains point                    │
│     • Hierarchical containment                  │
│                                                 │
│  5. Attribute Queries                           │
│     • Filter by category                        │
│     • Text search on names                      │
│     • Multi-criteria filtering                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 🔐 Data Quality Pipeline

```
Raw Data (Overture + OSM)
    │
    ├─→ Validation
    │     ├─ Coordinate range check
    │     ├─ Required fields check
    │     └─ Geometry validity
    │
    ├─→ Cleaning
    │     ├─ Remove duplicates
    │     ├─ Standardize formats
    │     └─ Fix encoding issues
    │
    ├─→ Enrichment
    │     ├─ Add missing fields
    │     ├─ Calculate derived fields
    │     └─ Add data source attribution
    │
    ├─→ Quality Scoring
    │     ├─ Completeness score
    │     ├─ Accuracy score
    │     └─ Confidence level
    │
    └─→ Master POI Table
```

## 📊 Performance Considerations

### Optimization Strategies

```
┌──────────────────────────────────────────────────┐
│  SMALL AREA (<10km²)                             │
│  • Direct API calls                              │
│  • In-memory processing                          │
│  • Single-threaded                               │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│  MEDIUM AREA (10-100km²)                         │
│  • Chunked processing                            │
│  • Streaming data                                │
│  • Multi-threaded                                │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│  LARGE AREA (>100km²)                            │
│  • DuckDB for Overture data                      │
│  • Geofabrik extracts for OSM                    │
│  • Distributed processing                        │
│  • Cloud computing resources                     │
└──────────────────────────────────────────────────┘
```

## 🌐 Deployment Architecture

```
Development
    │
    ├─→ Local Python environment
    └─→ Sample/test data

Production
    │
    ├─→ Cloud Environment (AWS/GCP/Azure)
    │     │
    │     ├─→ Compute (EC2/Compute Engine)
    │     ├─→ Storage (S3/Cloud Storage)
    │     └─→ Database (RDS/Cloud SQL)
    │
    └─→ Scheduling
          ├─→ Cron jobs
          ├─→ Airflow DAGs
          └─→ Lambda/Cloud Functions
```

---

**Architecture designed for scalability, performance, and maintainability** 🏗️