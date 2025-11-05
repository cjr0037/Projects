#!/usr/bin/env python3
"""
Example Usage Scripts for Master POI Table Creator

This file demonstrates various ways to use the POI table creator
for different use cases and scenarios.
"""

from create_master_poi_table import MasterPOITableCreator
import geopandas as gpd
import pandas as pd


def example_1_basic_usage():
    """
    Example 1: Basic usage - Create POI table and save to files
    """
    print("\n" + "="*80)
    print("EXAMPLE 1: Basic Usage")
    print("="*80)
    
    creator = MasterPOITableCreator(output_format='parquet')
    
    # Create POI table (uses sample data by default)
    poi_table = creator.create_master_poi_table(
        use_overture=True,
        use_osm=True,
        include_polygons=True
    )
    
    # Save to multiple formats
    creator.save_master_poi_table(poi_table, 'output/master_pois.parquet')
    creator.save_master_poi_table(poi_table, 'output/master_pois.csv')
    creator.save_master_poi_table(poi_table, 'output/master_pois.geojson')
    
    print(f"\nCreated POI table with {len(poi_table)} records")
    print("\nColumn names:")
    print(poi_table.columns.tolist())


def example_2_specific_area():
    """
    Example 2: Extract POIs for a specific geographic area
    """
    print("\n" + "="*80)
    print("EXAMPLE 2: Specific Geographic Area")
    print("="*80)
    
    creator = MasterPOITableCreator()
    
    # Define bounding box for San Francisco
    san_francisco_bbox = (-122.52, 37.70, -122.35, 37.82)
    
    poi_table = creator.create_master_poi_table(
        bbox=san_francisco_bbox,
        use_overture=True,
        use_osm=True,
        include_polygons=True
    )
    
    print(f"\nExtracted {len(poi_table)} POIs for San Francisco area")
    
    # Summary by category
    if len(poi_table) > 0:
        print("\nPOIs by Category:")
        print(poi_table['category'].value_counts().head(10))


def example_3_filter_and_analyze():
    """
    Example 3: Filter and analyze POI data
    """
    print("\n" + "="*80)
    print("EXAMPLE 3: Filter and Analyze")
    print("="*80)
    
    creator = MasterPOITableCreator()
    poi_table = creator.create_master_poi_table()
    
    # Filter by category
    restaurants = poi_table[poi_table['category'].isin(['amenity', 'restaurant'])]
    print(f"\nFound {len(restaurants)} restaurants")
    
    # Filter by location (example: New York)
    ny_pois = poi_table[poi_table['city'] == 'New York']
    print(f"Found {len(ny_pois)} POIs in New York")
    
    # Calculate statistics
    print("\nStatistics:")
    print(f"Total POIs: {len(poi_table)}")
    print(f"Unique categories: {poi_table['category'].nunique()}")
    print(f"POIs with phone numbers: {poi_table['phone'].notna().sum()}")
    print(f"POIs with websites: {poi_table['website'].notna().sum()}")


def example_4_spatial_queries():
    """
    Example 4: Perform spatial queries on POI data
    """
    print("\n" + "="*80)
    print("EXAMPLE 4: Spatial Queries")
    print("="*80)
    
    creator = MasterPOITableCreator()
    poi_table = creator.create_master_poi_table(include_polygons=True)
    
    # Find POIs near a specific point (Empire State Building)
    from shapely.geometry import Point
    
    target_point = Point(-73.985428, 40.748817)
    
    # Calculate distances (in degrees, approximate)
    poi_table['distance_to_target'] = poi_table.geometry.distance(target_point)
    
    # Find nearest POIs
    nearest_pois = poi_table.nsmallest(5, 'distance_to_target')
    
    print("\n5 Nearest POIs to Empire State Building:")
    for idx, row in nearest_pois.iterrows():
        print(f"  - {row['name']}: {row['distance_to_target']:.6f} degrees (~{row['distance_to_target']*111:.2f}km)")
    
    # Calculate polygon statistics
    if 'polygon_area_sqm' in poi_table.columns:
        avg_area = poi_table['polygon_area_sqm'].mean()
        print(f"\nAverage building area: {avg_area:.2f} square meters")


def example_5_export_to_database():
    """
    Example 5: Export POI data to PostgreSQL/PostGIS database
    """
    print("\n" + "="*80)
    print("EXAMPLE 5: Export to Database")
    print("="*80)
    
    creator = MasterPOITableCreator()
    poi_table = creator.create_master_poi_table()
    
    # Note: This requires a PostgreSQL/PostGIS database to be set up
    # Uncomment and configure the connection string when ready
    
    connection_string = "postgresql://username:password@localhost:5432/poi_database"
    
    print("\nTo export to database, uncomment and configure:")
    print(f"  creator.export_to_database(poi_table, '{connection_string}')")
    print("\nMake sure to:")
    print("  1. Install PostgreSQL and PostGIS")
    print("  2. Create database: createdb poi_database")
    print("  3. Run schema: psql poi_database < poi_schema.sql")
    
    # Uncomment to actually export:
    # creator.export_to_database(poi_table, connection_string, table_name='master_poi_table')


def example_6_custom_processing():
    """
    Example 6: Custom processing and enrichment
    """
    print("\n" + "="*80)
    print("EXAMPLE 6: Custom Processing")
    print("="*80)
    
    creator = MasterPOITableCreator()
    poi_table = creator.create_master_poi_table()
    
    # Add custom fields
    poi_table['has_contact'] = (poi_table['phone'].notna() | poi_table['website'].notna())
    poi_table['address_complete'] = poi_table['address'].notna() & (poi_table['address'] != '')
    
    # Create summary statistics
    print("\nData Completeness:")
    print(f"  POIs with contact info: {poi_table['has_contact'].sum()} ({poi_table['has_contact'].mean()*100:.1f}%)")
    print(f"  POIs with complete address: {poi_table['address_complete'].sum()} ({poi_table['address_complete'].mean()*100:.1f}%)")
    
    # Group by category and calculate metrics
    category_stats = poi_table.groupby('category').agg({
        'poi_id': 'count',
        'phone': lambda x: x.notna().sum(),
        'website': lambda x: x.notna().sum()
    }).rename(columns={'poi_id': 'count', 'phone': 'with_phone', 'website': 'with_website'})
    
    print("\nPOIs by Category:")
    print(category_stats.head(10))


def example_7_map_visualization():
    """
    Example 7: Create an interactive map visualization
    """
    print("\n" + "="*80)
    print("EXAMPLE 7: Map Visualization")
    print("="*80)
    
    try:
        import folium
        from folium import plugins
        
        creator = MasterPOITableCreator()
        poi_table = creator.create_master_poi_table()
        
        # Create base map centered on data
        center_lat = poi_table['latitude'].mean()
        center_lon = poi_table['longitude'].mean()
        
        m = folium.Map(location=[center_lat, center_lon], zoom_start=12)
        
        # Add POI markers
        for idx, row in poi_table.iterrows():
            folium.Marker(
                location=[row['latitude'], row['longitude']],
                popup=f"<b>{row['name']}</b><br>{row['category']}<br>{row['address']}",
                tooltip=row['name'],
                icon=folium.Icon(color='blue', icon='info-sign')
            ).add_to(m)
        
        # Add marker cluster
        marker_cluster = plugins.MarkerCluster().add_to(m)
        
        # Save map
        output_file = 'output/poi_map.html'
        m.save(output_file)
        print(f"\nInteractive map saved to: {output_file}")
        print("Open this file in a web browser to view the map")
        
    except ImportError:
        print("\nfolium package not installed. Install it with: pip install folium")


def example_8_bulk_processing():
    """
    Example 8: Bulk processing for multiple regions
    """
    print("\n" + "="*80)
    print("EXAMPLE 8: Bulk Processing")
    print("="*80)
    
    creator = MasterPOITableCreator()
    
    # Define multiple regions
    regions = {
        'nyc': (-74.02, 40.70, -73.92, 40.80),
        'sf': (-122.52, 37.70, -122.35, 37.82),
        'chicago': (-87.70, 41.80, -87.60, 41.95),
        'boston': (-71.12, 42.32, -71.00, 42.40)
    }
    
    all_results = {}
    
    print("\nProcessing multiple regions:")
    for region_name, bbox in regions.items():
        print(f"\n  Processing {region_name}...")
        
        poi_table = creator.create_master_poi_table(
            bbox=None,  # Using None for sample data; set to bbox for real data
            use_overture=True,
            use_osm=False
        )
        
        all_results[region_name] = poi_table
        print(f"    Found {len(poi_table)} POIs")
    
    # Combine all regions
    combined = pd.concat(all_results.values(), ignore_index=True)
    print(f"\nTotal POIs across all regions: {len(combined)}")
    
    # Save combined dataset
    creator.save_master_poi_table(combined, 'output/combined_regions.parquet')


def run_all_examples():
    """Run all examples"""
    import os
    
    # Create output directory
    os.makedirs('output', exist_ok=True)
    
    print("\n" + "#"*80)
    print("# Master POI Table Creator - Example Usage Scripts")
    print("#"*80)
    
    examples = [
        example_1_basic_usage,
        example_2_specific_area,
        example_3_filter_and_analyze,
        example_4_spatial_queries,
        example_5_export_to_database,
        example_6_custom_processing,
        example_7_map_visualization,
        example_8_bulk_processing
    ]
    
    for i, example in enumerate(examples, 1):
        try:
            example()
        except Exception as e:
            print(f"\nError in example {i}: {e}")
        
        if i < len(examples):
            input("\nPress Enter to continue to next example...")
    
    print("\n" + "#"*80)
    print("# All examples completed!")
    print("#"*80)


if __name__ == "__main__":
    run_all_examples()