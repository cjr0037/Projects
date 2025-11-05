-- Master POI Table Schema for PostgreSQL/PostGIS
-- This schema defines the structure for storing Points of Interest with geospatial data

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop existing table if needed
DROP TABLE IF EXISTS master_poi_table CASCADE;

-- Create the master POI table
CREATE TABLE master_poi_table (
    -- Primary identifier
    poi_id VARCHAR(50) PRIMARY KEY,
    
    -- Core POI information
    name VARCHAR(500) NOT NULL,
    category VARCHAR(100),
    subcategory VARCHAR(100),
    
    -- Address components
    address TEXT,
    street VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    
    -- Contact information
    phone VARCHAR(50),
    website VARCHAR(500),
    email VARCHAR(200),
    
    -- Location coordinates (point geometry)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    geometry GEOMETRY(Point, 4326),  -- WGS84 coordinate system
    
    -- Building/area polygon (if available)
    building_polygon GEOMETRY(Polygon, 4326),
    polygon_area_sqm DECIMAL(15, 2),
    
    -- Additional metadata
    opening_hours TEXT,
    description TEXT,
    rating DECIMAL(3, 2),
    review_count INTEGER,
    price_level VARCHAR(20),
    
    -- Data provenance
    data_source VARCHAR(100),
    source_id VARCHAR(100),
    confidence DECIMAL(3, 2),
    last_verified TIMESTAMP,
    
    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Additional tags/attributes (JSON for flexibility)
    tags JSONB,
    attributes JSONB
);

-- Create spatial indices for performance
CREATE INDEX idx_poi_geometry ON master_poi_table USING GIST (geometry);
CREATE INDEX idx_poi_building_polygon ON master_poi_table USING GIST (building_polygon);

-- Create indices on commonly queried fields
CREATE INDEX idx_poi_category ON master_poi_table (category);
CREATE INDEX idx_poi_city ON master_poi_table (city);
CREATE INDEX idx_poi_state ON master_poi_table (state);
CREATE INDEX idx_poi_country ON master_poi_table (country);
CREATE INDEX idx_poi_data_source ON master_poi_table (data_source);

-- Create full-text search index on name and description
CREATE INDEX idx_poi_name_fts ON master_poi_table USING GIN (to_tsvector('english', name));
CREATE INDEX idx_poi_description_fts ON master_poi_table USING GIN (to_tsvector('english', description));

-- Create GIN index on JSONB fields
CREATE INDEX idx_poi_tags ON master_poi_table USING GIN (tags);
CREATE INDEX idx_poi_attributes ON master_poi_table USING GIN (attributes);

-- Create trigger to automatically update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_poi_modtime
    BEFORE UPDATE ON master_poi_table
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- Create view for easy querying with computed fields
CREATE OR REPLACE VIEW vw_poi_summary AS
SELECT 
    poi_id,
    name,
    category,
    subcategory,
    address,
    city,
    state,
    country,
    latitude,
    longitude,
    phone,
    website,
    data_source,
    ST_AsText(geometry) as geometry_wkt,
    ST_AsGeoJSON(geometry) as geometry_geojson,
    ST_AsText(building_polygon) as building_polygon_wkt,
    polygon_area_sqm,
    created_at
FROM master_poi_table;

-- Create materialized view for spatial analysis
CREATE MATERIALIZED VIEW mv_poi_density AS
SELECT 
    category,
    city,
    state,
    COUNT(*) as poi_count,
    ST_ConvexHull(ST_Collect(geometry)) as coverage_area,
    AVG(rating) as avg_rating
FROM master_poi_table
WHERE geometry IS NOT NULL
GROUP BY category, city, state;

CREATE INDEX idx_mv_poi_density_geometry ON mv_poi_density USING GIST (coverage_area);

-- Sample queries:

-- 1. Find POIs within a bounding box
-- SELECT * FROM master_poi_table
-- WHERE geometry && ST_MakeEnvelope(-74.02, 40.70, -73.92, 40.80, 4326);

-- 2. Find POIs within a radius of a point (e.g., 1km)
-- SELECT poi_id, name, category, 
--        ST_Distance(geometry::geography, ST_SetSRID(ST_MakePoint(-73.985428, 40.748817), 4326)::geography) as distance_meters
-- FROM master_poi_table
-- WHERE ST_DWithin(geometry::geography, ST_SetSRID(ST_MakePoint(-73.985428, 40.748817), 4326)::geography, 1000)
-- ORDER BY distance_meters;

-- 3. Find POIs by category and city
-- SELECT * FROM master_poi_table
-- WHERE category = 'restaurant' AND city = 'New York';

-- 4. Full-text search on POI names
-- SELECT * FROM master_poi_table
-- WHERE to_tsvector('english', name) @@ to_tsquery('english', 'coffee | cafe');

-- 5. Get POI count by category
-- SELECT category, COUNT(*) as count
-- FROM master_poi_table
-- GROUP BY category
-- ORDER BY count DESC;

COMMENT ON TABLE master_poi_table IS 'Master table containing Points of Interest from open source data (Overture Maps, OpenStreetMap)';
COMMENT ON COLUMN master_poi_table.poi_id IS 'Unique identifier for the POI';
COMMENT ON COLUMN master_poi_table.geometry IS 'Point geometry in WGS84 (EPSG:4326)';
COMMENT ON COLUMN master_poi_table.building_polygon IS 'Associated building or area polygon';
COMMENT ON COLUMN master_poi_table.data_source IS 'Source of the data (e.g., Overture Maps, OpenStreetMap)';