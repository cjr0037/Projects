#!/usr/bin/env python3
"""
Simple POI Table Generator - No External Dependencies Required
Creates a CSV file with sample POI data that demonstrates the structure
"""

import csv
import json
from datetime import datetime


def generate_sample_poi_data():
    """Generate sample POI data for demonstration"""
    
    sample_pois = [
        {
            'poi_id': 'POI_000001',
            'name': 'Central Park',
            'category': 'park',
            'subcategory': 'urban_park',
            'address': 'Manhattan, New York, NY 10022',
            'street': '5th Avenue',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10022',
            'country': 'USA',
            'latitude': 40.785091,
            'longitude': -73.968285,
            'phone': '+1-212-310-6600',
            'website': 'https://www.centralparknyc.org',
            'opening_hours': '6:00 AM - 1:00 AM',
            'polygon_wkt': 'POLYGON((-73.97 40.78, -73.95 40.78, -73.95 40.80, -73.97 40.80, -73.97 40.78))',
            'polygon_area_sqm': 341505.8,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000002',
            'name': 'Empire State Building',
            'category': 'tourism',
            'subcategory': 'attraction',
            'address': '20 W 34th St, New York, NY 10001',
            'street': 'W 34th St',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10001',
            'country': 'USA',
            'latitude': 40.748817,
            'longitude': -73.985428,
            'phone': '+1-212-736-3100',
            'website': 'https://www.esbnyc.com',
            'opening_hours': '8:00 AM - 2:00 AM',
            'polygon_wkt': 'POLYGON((-73.986 40.748, -73.984 40.748, -73.984 40.750, -73.986 40.750, -73.986 40.748))',
            'polygon_area_sqm': 8094.0,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000003',
            'name': 'Whole Foods Market',
            'category': 'shop',
            'subcategory': 'supermarket',
            'address': '250 7th Ave, New York, NY 10001',
            'street': '7th Avenue',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10001',
            'country': 'USA',
            'latitude': 40.746740,
            'longitude': -73.993753,
            'phone': '+1-212-924-5969',
            'website': 'https://www.wholefoodsmarket.com',
            'opening_hours': '8:00 AM - 10:00 PM',
            'polygon_wkt': 'POLYGON((-73.994 40.746, -73.993 40.746, -73.993 40.747, -73.994 40.747, -73.994 40.746))',
            'polygon_area_sqm': 3500.0,
            'data_source': 'OpenStreetMap',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000004',
            'name': 'Starbucks',
            'category': 'amenity',
            'subcategory': 'cafe',
            'address': '341 5th Ave, New York, NY 10016',
            'street': '5th Avenue',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10016',
            'country': 'USA',
            'latitude': 40.746590,
            'longitude': -73.983340,
            'phone': '+1-212-532-7620',
            'website': 'https://www.starbucks.com',
            'opening_hours': '6:00 AM - 9:00 PM',
            'polygon_wkt': 'POLYGON((-73.984 40.746, -73.983 40.746, -73.983 40.747, -73.984 40.747, -73.984 40.746))',
            'polygon_area_sqm': 250.0,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000005',
            'name': 'Bryant Park',
            'category': 'leisure',
            'subcategory': 'park',
            'address': 'Bryant Park, New York, NY 10018',
            'street': '6th Avenue',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10018',
            'country': 'USA',
            'latitude': 40.753597,
            'longitude': -73.983233,
            'phone': '+1-212-768-4242',
            'website': 'https://bryantpark.org',
            'opening_hours': '7:00 AM - 10:00 PM',
            'polygon_wkt': 'POLYGON((-73.984 40.753, -73.982 40.753, -73.982 40.754, -73.984 40.754, -73.984 40.753))',
            'polygon_area_sqm': 39000.0,
            'data_source': 'OpenStreetMap',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000006',
            'name': 'Times Square',
            'category': 'tourism',
            'subcategory': 'attraction',
            'address': 'Manhattan, New York, NY 10036',
            'street': 'Broadway',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10036',
            'country': 'USA',
            'latitude': 40.758896,
            'longitude': -73.985130,
            'phone': '',
            'website': 'https://www.timessquarenyc.org',
            'opening_hours': '24/7',
            'polygon_wkt': 'POLYGON((-73.987 40.757, -73.983 40.757, -73.983 40.760, -73.987 40.760, -73.987 40.757))',
            'polygon_area_sqm': 55000.0,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000007',
            'name': 'Grand Central Terminal',
            'category': 'transport',
            'subcategory': 'train_station',
            'address': '89 E 42nd St, New York, NY 10017',
            'street': 'E 42nd St',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10017',
            'country': 'USA',
            'latitude': 40.752655,
            'longitude': -73.977295,
            'phone': '+1-212-340-2583',
            'website': 'https://www.grandcentralterminal.com',
            'opening_hours': '5:30 AM - 2:00 AM',
            'polygon_wkt': 'POLYGON((-73.978 40.752, -73.976 40.752, -73.976 40.753, -73.978 40.753, -73.978 40.752))',
            'polygon_area_sqm': 12000.0,
            'data_source': 'OpenStreetMap',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000008',
            'name': 'The Metropolitan Museum of Art',
            'category': 'tourism',
            'subcategory': 'museum',
            'address': '1000 5th Ave, New York, NY 10028',
            'street': '5th Avenue',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10028',
            'country': 'USA',
            'latitude': 40.779437,
            'longitude': -73.963244,
            'phone': '+1-212-535-7710',
            'website': 'https://www.metmuseum.org',
            'opening_hours': '10:00 AM - 5:00 PM',
            'polygon_wkt': 'POLYGON((-73.965 40.778, -73.961 40.778, -73.961 40.781, -73.965 40.781, -73.965 40.778))',
            'polygon_area_sqm': 180000.0,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000009',
            'name': 'Madison Square Garden',
            'category': 'entertainment',
            'subcategory': 'arena',
            'address': '4 Pennsylvania Plaza, New York, NY 10001',
            'street': 'Pennsylvania Plaza',
            'city': 'New York',
            'state': 'NY',
            'postal_code': '10001',
            'country': 'USA',
            'latitude': 40.750504,
            'longitude': -73.993439,
            'phone': '+1-212-465-6741',
            'website': 'https://www.msg.com',
            'opening_hours': 'Varies by event',
            'polygon_wkt': 'POLYGON((-73.994 40.750, -73.992 40.750, -73.992 40.751, -73.994 40.751, -73.994 40.750))',
            'polygon_area_sqm': 42000.0,
            'data_source': 'Overture Maps',
            'created_at': datetime.now().isoformat()
        },
        {
            'poi_id': 'POI_000010',
            'name': 'Brooklyn Bridge Park',
            'category': 'park',
            'subcategory': 'waterfront_park',
            'address': 'Brooklyn, NY 11201',
            'street': 'Furman Street',
            'city': 'Brooklyn',
            'state': 'NY',
            'postal_code': '11201',
            'country': 'USA',
            'latitude': 40.700292,
            'longitude': -73.996864,
            'phone': '+1-718-222-9939',
            'website': 'https://www.brooklynbridgepark.org',
            'opening_hours': '6:00 AM - 1:00 AM',
            'polygon_wkt': 'POLYGON((-73.998 40.699, -73.995 40.699, -73.995 40.701, -73.998 40.701, -73.998 40.699))',
            'polygon_area_sqm': 34000.0,
            'data_source': 'OpenStreetMap',
            'created_at': datetime.now().isoformat()
        }
    ]
    
    return sample_pois


def save_as_csv(pois, filename='master_poi_table.csv'):
    """Save POI data as CSV file"""
    
    if not pois:
        print("No POI data to save")
        return
    
    fieldnames = pois[0].keys()
    
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(pois)
    
    print(f"✅ Saved CSV file: {filename}")
    return filename


def save_as_json(pois, filename='master_poi_table.json'):
    """Save POI data as JSON file"""
    
    with open(filename, 'w', encoding='utf-8') as jsonfile:
        json.dump(pois, jsonfile, indent=2)
    
    print(f"✅ Saved JSON file: {filename}")
    return filename


def save_as_geojson(pois, filename='master_poi_table.geojson'):
    """Save POI data as GeoJSON file"""
    
    features = []
    for poi in pois:
        feature = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [poi['longitude'], poi['latitude']]
            },
            "properties": {k: v for k, v in poi.items() if k not in ['latitude', 'longitude']}
        }
        features.append(feature)
    
    geojson = {
        "type": "FeatureCollection",
        "features": features
    }
    
    with open(filename, 'w', encoding='utf-8') as geofile:
        json.dump(geojson, geofile, indent=2)
    
    print(f"✅ Saved GeoJSON file: {filename}")
    return filename


def print_sample_records(pois, num_records=3):
    """Print sample POI records"""
    
    print("\n" + "="*80)
    print(f"SAMPLE POI RECORDS (showing {num_records} of {len(pois)})")
    print("="*80 + "\n")
    
    for i, poi in enumerate(pois[:num_records], 1):
        print(f"POI #{i}:")
        print(f"  Name: {poi['name']}")
        print(f"  Category: {poi['category']} ({poi['subcategory']})")
        print(f"  Location: {poi['latitude']}, {poi['longitude']}")
        print(f"  Address: {poi['address']}")
        print(f"  Phone: {poi['phone']}")
        print(f"  Website: {poi['website']}")
        print(f"  Area: {poi['polygon_area_sqm']} sqm")
        print(f"  Source: {poi['data_source']}")
        print()


def main():
    """Main execution function"""
    
    print("\n" + "="*80)
    print("MASTER POI TABLE GENERATOR - Sample Data")
    print("="*80 + "\n")
    
    # Generate sample POI data
    print("📍 Generating sample POI data...")
    pois = generate_sample_poi_data()
    print(f"   Generated {len(pois)} sample POIs\n")
    
    # Save in multiple formats
    print("💾 Saving POI table in multiple formats...\n")
    csv_file = save_as_csv(pois, 'master_poi_table.csv')
    json_file = save_as_json(pois, 'master_poi_table.json')
    geojson_file = save_as_geojson(pois, 'master_poi_table.geojson')
    
    # Print sample records
    print_sample_records(pois, num_records=3)
    
    # Summary
    print("="*80)
    print("✅ POI TABLE GENERATION COMPLETE!")
    print("="*80)
    print("\n📁 Files created in current directory:")
    print(f"   • master_poi_table.csv     (Excel/spreadsheet compatible)")
    print(f"   • master_poi_table.json    (JSON format)")
    print(f"   • master_poi_table.geojson (Web mapping compatible)")
    
    print("\n📊 Table contains:")
    print(f"   • {len(pois)} POI records")
    print(f"   • Latitude & longitude coordinates")
    print(f"   • Associated polygon geometries (WKT format)")
    print(f"   • Location metadata (name, category, subcategory)")
    print(f"   • Address data (street, city, state, postal code, country)")
    print(f"   • Contact info (phone, website, hours)")
    
    print("\n🔍 How to access the data:")
    print("\n   1. CSV File (Excel/Spreadsheet):")
    print("      - Open master_poi_table.csv in Excel, Google Sheets, etc.")
    print("      - Or use any text editor")
    
    print("\n   2. Python:")
    print("      import pandas as pd")
    print("      pois = pd.read_csv('master_poi_table.csv')")
    print("      print(pois.head())")
    
    print("\n   3. JSON:")
    print("      import json")
    print("      with open('master_poi_table.json') as f:")
    print("          pois = json.load(f)")
    
    print("\n   4. Web Mapping:")
    print("      - Upload master_poi_table.geojson to:")
    print("        • https://geojson.io")
    print("        • https://kepler.gl")
    print("        • QGIS, ArcGIS, etc.")
    
    print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    main()