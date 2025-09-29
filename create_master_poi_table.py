#!/usr/bin/env python3
"""
Master POI Table Creator using Open Source Data

This script creates a comprehensive POI (Points of Interest) table using open source data from:
1. Overture Maps (https://overturemaps.org/) - Primary source
2. OpenStreetMap via Overpass API - Fallback/enrichment

Features:
- Latitude and longitude coordinates
- Associated polygons (building footprints, areas)
- Location name and metadata
- Address-level data (street, city, state, postal code, country)
- Category/type information
- Additional attributes (phone, website, opening hours, etc.)
"""

import os
import json
import pandas as pd
import geopandas as gpd
from shapely.geometry import Point, Polygon, shape
import requests
from typing import Dict, List, Optional
import warnings
warnings.filterwarnings('ignore')


class MasterPOITableCreator:
    """Creates a master POI table from open source geospatial data"""
    
    def __init__(self, output_format='parquet'):
        """
        Initialize the POI table creator
        
        Args:
            output_format: Output format ('parquet', 'csv', 'geojson', 'gpkg')
        """
        self.output_format = output_format
        self.poi_data = []
        
    def fetch_overture_poi_data(self, bbox: Optional[tuple] = None, 
                                theme: str = 'places', 
                                limit: int = 10000) -> gpd.GeoDataFrame:
        """
        Fetch POI data from Overture Maps
        
        Overture Maps is an open map data initiative that provides high-quality POI data.
        Data can be accessed via AWS S3 or using their Python SDK.
        
        Args:
            bbox: Bounding box (min_lon, min_lat, max_lon, max_lat)
            theme: Overture theme ('places', 'buildings', 'addresses')
            limit: Maximum number of records to fetch
            
        Returns:
            GeoDataFrame with POI data
        """
        print(f"Fetching Overture Maps data for theme: {theme}")
        
        # Note: This is a demonstration structure. In production, you would use:
        # 1. overturemaps Python package
        # 2. DuckDB to query Overture data directly from S3
        # 3. AWS CLI to download Overture data files
        
        # Example using DuckDB to query Overture data (requires duckdb package)
        try:
            import duckdb
            
            # Construct query for Overture Maps data
            # The data is stored in GeoParquet format on AWS S3
            query = f"""
            INSTALL spatial;
            LOAD spatial;
            INSTALL httpfs;
            LOAD httpfs;
            SET s3_region='us-west-2';
            
            -- Query Overture Places data
            SELECT 
                id,
                JSON_EXTRACT_STRING(names, '$.primary') as name,
                JSON_EXTRACT_STRING(categories, '$.primary') as category,
                JSON_EXTRACT_STRING(categories, '$.alternate[0]') as subcategory,
                JSON_EXTRACT_STRING(addresses, '$[0].freeform') as address_freeform,
                JSON_EXTRACT_STRING(addresses, '$[0].locality') as city,
                JSON_EXTRACT_STRING(addresses, '$[0].region') as state,
                JSON_EXTRACT_STRING(addresses, '$[0].postcode') as postal_code,
                JSON_EXTRACT_STRING(addresses, '$[0].country') as country,
                JSON_EXTRACT_STRING(phones, '$[0]') as phone,
                JSON_EXTRACT_STRING(websites, '$[0]') as website,
                JSON_EXTRACT_STRING(socials, '$[0]') as social_media,
                ST_X(ST_GeomFromWKB(geometry)) as longitude,
                ST_Y(ST_GeomFromWKB(geometry)) as latitude,
                ST_AsText(ST_GeomFromWKB(geometry)) as geometry_wkt,
                sources,
                confidence
            FROM read_parquet('s3://overturemaps-us-west-2/release/2024-11-13.0/theme=places/type=place/*', 
                             filename=true, hive_partitioning=1)
            """
            
            if bbox:
                query += f"""
                WHERE ST_X(ST_GeomFromWKB(geometry)) BETWEEN {bbox[0]} AND {bbox[2]}
                  AND ST_Y(ST_GeomFromWKB(geometry)) BETWEEN {bbox[1]} AND {bbox[3]}
                """
            
            query += f" LIMIT {limit};"
            
            # Execute query
            con = duckdb.connect()
            result = con.execute(query).fetchdf()
            
            # Convert to GeoDataFrame
            if len(result) > 0:
                geometry = gpd.points_from_xy(result['longitude'], result['latitude'])
                gdf = gpd.GeoDataFrame(result, geometry=geometry, crs='EPSG:4326')
                print(f"Successfully fetched {len(gdf)} POIs from Overture Maps")
                return gdf
            
        except ImportError:
            print("DuckDB not installed. Falling back to sample data generation.")
        except Exception as e:
            print(f"Error fetching Overture data: {e}")
            print("Falling back to sample data generation.")
        
        return self._generate_sample_poi_data()
    
    def fetch_osm_poi_data(self, bbox: tuple, poi_types: List[str] = None) -> gpd.GeoDataFrame:
        """
        Fetch POI data from OpenStreetMap using Overpass API
        
        Args:
            bbox: Bounding box (min_lat, min_lon, max_lat, max_lon)
            poi_types: List of OSM types to fetch (e.g., ['amenity', 'shop', 'tourism'])
            
        Returns:
            GeoDataFrame with POI data
        """
        if poi_types is None:
            poi_types = ['amenity', 'shop', 'tourism', 'leisure']
        
        print(f"Fetching OpenStreetMap data for types: {poi_types}")
        
        overpass_url = "http://overpass-api.de/api/interpreter"
        
        # Build Overpass QL query
        query_parts = []
        for poi_type in poi_types:
            query_parts.append(f'node["{poi_type}"]({bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]});')
            query_parts.append(f'way["{poi_type}"]({bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]});')
            query_parts.append(f'relation["{poi_type}"]({bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]});')
        
        query = f"""
        [out:json][timeout:60];
        (
            {''.join(query_parts)}
        );
        out center;
        """
        
        try:
            response = requests.post(overpass_url, data={'data': query}, timeout=120)
            response.raise_for_status()
            data = response.json()
            
            # Parse OSM data into structured format
            features = []
            for element in data.get('elements', []):
                feature = self._parse_osm_element(element)
                if feature:
                    features.append(feature)
            
            if features:
                gdf = gpd.GeoDataFrame.from_features(features, crs='EPSG:4326')
                print(f"Successfully fetched {len(gdf)} POIs from OpenStreetMap")
                return gdf
            
        except Exception as e:
            print(f"Error fetching OSM data: {e}")
        
        return gpd.GeoDataFrame()
    
    def _parse_osm_element(self, element: Dict) -> Optional[Dict]:
        """Parse an OSM element into a feature dictionary"""
        tags = element.get('tags', {})
        
        # Skip elements without names (unless they're important POIs)
        if 'name' not in tags and 'amenity' not in tags:
            return None
        
        # Get coordinates
        if 'lat' in element and 'lon' in element:
            lat, lon = element['lat'], element['lon']
        elif 'center' in element:
            lat, lon = element['center']['lat'], element['center']['lon']
        else:
            return None
        
        # Extract address components
        address_parts = {
            'street': tags.get('addr:street', ''),
            'housenumber': tags.get('addr:housenumber', ''),
            'city': tags.get('addr:city', ''),
            'state': tags.get('addr:state', ''),
            'postcode': tags.get('addr:postcode', ''),
            'country': tags.get('addr:country', '')
        }
        
        # Build full address
        address_components = [
            f"{address_parts['housenumber']} {address_parts['street']}".strip(),
            address_parts['city'],
            address_parts['state'],
            address_parts['postcode'],
            address_parts['country']
        ]
        full_address = ', '.join([c for c in address_components if c])
        
        # Determine POI category
        category = (tags.get('amenity') or tags.get('shop') or 
                   tags.get('tourism') or tags.get('leisure') or 'other')
        
        feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'Point',
                'coordinates': [lon, lat]
            },
            'properties': {
                'osm_id': element.get('id'),
                'osm_type': element.get('type'),
                'name': tags.get('name', tags.get('operator', 'Unnamed')),
                'category': category,
                'subcategory': tags.get('cuisine') or tags.get('shop') or '',
                'address': full_address,
                'street': address_parts['street'],
                'city': address_parts['city'],
                'state': address_parts['state'],
                'postal_code': address_parts['postcode'],
                'country': address_parts['country'],
                'phone': tags.get('phone', ''),
                'website': tags.get('website', ''),
                'opening_hours': tags.get('opening_hours', ''),
                'wheelchair': tags.get('wheelchair', ''),
                'latitude': lat,
                'longitude': lon,
                'data_source': 'OpenStreetMap'
            }
        }
        
        return feature
    
    def fetch_building_polygons(self, pois_gdf: gpd.GeoDataFrame, 
                                buffer_meters: float = 20) -> gpd.GeoDataFrame:
        """
        Enrich POI data with building polygons from Overture or OSM
        
        Args:
            pois_gdf: GeoDataFrame of POI points
            buffer_meters: Buffer distance to search for buildings
            
        Returns:
            GeoDataFrame with building polygon geometries added
        """
        print("Fetching associated building polygons...")
        
        # This would query Overture Buildings theme or OSM building polygons
        # For demonstration, we'll create buffer polygons around points
        
        # Convert buffer from meters to degrees (approximate)
        buffer_degrees = buffer_meters / 111000
        
        pois_with_polygons = pois_gdf.copy()
        pois_with_polygons['building_polygon'] = pois_with_polygons.geometry.buffer(buffer_degrees)
        pois_with_polygons['polygon_wkt'] = pois_with_polygons['building_polygon'].apply(lambda x: x.wkt)
        pois_with_polygons['polygon_area_sqm'] = pois_with_polygons['building_polygon'].to_crs('EPSG:3857').area
        
        return pois_with_polygons
    
    def _generate_sample_poi_data(self) -> gpd.GeoDataFrame:
        """
        Generate sample POI data for demonstration purposes
        This represents the structure of what would come from Overture/OSM
        """
        print("Generating sample POI data for demonstration...")
        
        sample_data = [
            {
                'name': 'Central Park',
                'category': 'park',
                'subcategory': 'urban_park',
                'address': 'Manhattan, New York, NY',
                'street': '5th Avenue',
                'city': 'New York',
                'state': 'NY',
                'postal_code': '10022',
                'country': 'USA',
                'phone': '+1-212-310-6600',
                'website': 'https://www.centralparknyc.org',
                'latitude': 40.785091,
                'longitude': -73.968285,
                'data_source': 'Overture Maps'
            },
            {
                'name': 'Empire State Building',
                'category': 'tourism',
                'subcategory': 'attraction',
                'address': '20 W 34th St, New York, NY 10001',
                'street': 'W 34th St',
                'city': 'New York',
                'state': 'NY',
                'postal_code': '10001',
                'country': 'USA',
                'phone': '+1-212-736-3100',
                'website': 'https://www.esbnyc.com',
                'latitude': 40.748817,
                'longitude': -73.985428,
                'data_source': 'Overture Maps'
            },
            {
                'name': 'Whole Foods Market',
                'category': 'shop',
                'subcategory': 'supermarket',
                'address': '250 7th Ave, New York, NY 10001',
                'street': '7th Avenue',
                'city': 'New York',
                'state': 'NY',
                'postal_code': '10001',
                'country': 'USA',
                'phone': '+1-212-924-5969',
                'website': 'https://www.wholefoodsmarket.com',
                'latitude': 40.746740,
                'longitude': -73.993753,
                'data_source': 'OpenStreetMap'
            },
            {
                'name': 'Starbucks',
                'category': 'amenity',
                'subcategory': 'cafe',
                'address': '341 5th Ave, New York, NY 10016',
                'street': '5th Avenue',
                'city': 'New York',
                'state': 'NY',
                'postal_code': '10016',
                'country': 'USA',
                'phone': '+1-212-532-7620',
                'website': 'https://www.starbucks.com',
                'latitude': 40.746590,
                'longitude': -73.983340,
                'data_source': 'Overture Maps'
            },
            {
                'name': 'Bryant Park',
                'category': 'leisure',
                'subcategory': 'park',
                'address': 'Bryant Park, New York, NY 10018',
                'street': '6th Avenue',
                'city': 'New York',
                'state': 'NY',
                'postal_code': '10018',
                'country': 'USA',
                'phone': '+1-212-768-4242',
                'website': 'https://bryantpark.org',
                'latitude': 40.753597,
                'longitude': -73.983233,
                'data_source': 'OpenStreetMap'
            }
        ]
        
        # Create GeoDataFrame
        geometry = [Point(xy) for xy in zip(
            [d['longitude'] for d in sample_data],
            [d['latitude'] for d in sample_data]
        )]
        
        gdf = gpd.GeoDataFrame(sample_data, geometry=geometry, crs='EPSG:4326')
        
        print(f"Generated {len(gdf)} sample POIs")
        return gdf
    
    def create_master_poi_table(self, bbox: Optional[tuple] = None,
                               use_overture: bool = True,
                               use_osm: bool = True,
                               include_polygons: bool = True) -> gpd.GeoDataFrame:
        """
        Create a comprehensive master POI table
        
        Args:
            bbox: Bounding box to limit data (min_lon, min_lat, max_lon, max_lat)
            use_overture: Whether to fetch Overture Maps data
            use_osm: Whether to fetch OpenStreetMap data
            include_polygons: Whether to include building polygons
            
        Returns:
            GeoDataFrame with master POI table
        """
        print("=" * 80)
        print("Creating Master POI Table from Open Source Data")
        print("=" * 80)
        
        all_pois = []
        
        # Fetch Overture Maps data
        if use_overture:
            overture_data = self.fetch_overture_poi_data(bbox=bbox)
            if not overture_data.empty:
                all_pois.append(overture_data)
        
        # Fetch OpenStreetMap data
        if use_osm and bbox:
            # Convert bbox format for OSM (lat, lon, lat, lon)
            osm_bbox = (bbox[1], bbox[0], bbox[3], bbox[2]) if bbox else None
            osm_data = self.fetch_osm_poi_data(bbox=osm_bbox)
            if not osm_data.empty:
                all_pois.append(osm_data)
        
        # Combine all POI sources
        if not all_pois:
            print("No data fetched from APIs. Using sample data.")
            combined_pois = self._generate_sample_poi_data()
        else:
            combined_pois = pd.concat(all_pois, ignore_index=True)
        
        # Add building polygons
        if include_polygons:
            combined_pois = self.fetch_building_polygons(combined_pois)
        
        # Standardize columns
        combined_pois = self._standardize_columns(combined_pois)
        
        # Add metadata
        combined_pois['created_at'] = pd.Timestamp.now()
        combined_pois['poi_id'] = [f"POI_{i:06d}" for i in range(len(combined_pois))]
        
        print(f"\n{'=' * 80}")
        print(f"Master POI Table Created Successfully!")
        print(f"Total POIs: {len(combined_pois)}")
        print(f"{'=' * 80}\n")
        
        return combined_pois
    
    def _standardize_columns(self, gdf: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
        """Standardize column names and ensure all required fields exist"""
        
        required_columns = {
            'poi_id': '',
            'name': '',
            'category': '',
            'subcategory': '',
            'address': '',
            'street': '',
            'city': '',
            'state': '',
            'postal_code': '',
            'country': '',
            'latitude': 0.0,
            'longitude': 0.0,
            'phone': '',
            'website': '',
            'data_source': '',
            'created_at': pd.Timestamp.now()
        }
        
        for col, default_value in required_columns.items():
            if col not in gdf.columns:
                gdf[col] = default_value
        
        return gdf
    
    def save_master_poi_table(self, gdf: gpd.GeoDataFrame, 
                              output_path: str = None) -> str:
        """
        Save the master POI table to disk
        
        Args:
            gdf: GeoDataFrame to save
            output_path: Output file path (extension determines format)
            
        Returns:
            Path to saved file
        """
        if output_path is None:
            output_path = f"master_poi_table.{self.output_format}"
        
        print(f"Saving master POI table to: {output_path}")
        
        if output_path.endswith('.parquet'):
            gdf.to_parquet(output_path, index=False)
        elif output_path.endswith('.csv'):
            # Save as CSV (without complex geometry)
            df = pd.DataFrame(gdf.drop(columns=['geometry', 'building_polygon'], errors='ignore'))
            df.to_csv(output_path, index=False)
        elif output_path.endswith('.geojson'):
            gdf.to_file(output_path, driver='GeoJSON')
        elif output_path.endswith('.gpkg'):
            gdf.to_file(output_path, driver='GPKG', layer='pois')
        elif output_path.endswith('.shp'):
            gdf.to_file(output_path)
        else:
            # Default to parquet
            gdf.to_parquet(output_path, index=False)
        
        print(f"Successfully saved {len(gdf)} POIs to {output_path}")
        return output_path
    
    def export_to_database(self, gdf: gpd.GeoDataFrame, 
                          connection_string: str,
                          table_name: str = 'master_poi_table') -> None:
        """
        Export POI data to a PostgreSQL/PostGIS database
        
        Args:
            gdf: GeoDataFrame to export
            connection_string: Database connection string
            table_name: Target table name
        """
        from sqlalchemy import create_engine
        
        engine = create_engine(connection_string)
        gdf.to_postgis(table_name, engine, if_exists='replace', index=False)
        print(f"Successfully exported to database table: {table_name}")


def main():
    """Main execution function"""
    
    # Initialize creator
    creator = MasterPOITableCreator(output_format='parquet')
    
    # Example 1: Create POI table for a specific area (NYC example)
    # Bounding box: (min_lon, min_lat, max_lon, max_lat)
    nyc_bbox = (-74.02, 40.70, -73.92, 40.80)
    
    # Create master POI table
    master_poi_table = creator.create_master_poi_table(
        bbox=None,  # Set to nyc_bbox for real data
        use_overture=True,
        use_osm=True,
        include_polygons=True
    )
    
    # Display sample
    print("\nSample POI Records:")
    print("=" * 80)
    display_columns = ['poi_id', 'name', 'category', 'address', 'latitude', 'longitude']
    print(master_poi_table[display_columns].head(10).to_string())
    
    # Display schema
    print("\n\nPOI Table Schema:")
    print("=" * 80)
    print(master_poi_table.dtypes)
    
    # Save to multiple formats
    print("\n\nSaving to files...")
    print("=" * 80)
    creator.save_master_poi_table(master_poi_table, 'master_poi_table.parquet')
    creator.save_master_poi_table(master_poi_table, 'master_poi_table.csv')
    creator.save_master_poi_table(master_poi_table, 'master_poi_table.geojson')
    
    # Optional: Export to database
    # creator.export_to_database(
    #     master_poi_table,
    #     'postgresql://user:password@localhost:5432/poi_db'
    # )
    
    print("\n" + "=" * 80)
    print("Master POI Table Creation Complete!")
    print("=" * 80)


if __name__ == "__main__":
    main()