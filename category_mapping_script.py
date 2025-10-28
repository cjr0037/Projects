#!/usr/bin/env python3
"""
Overture Map to Foursquare Category Mapping Script

This script maps Overture Map POI categories to the closest matching Foursquare categories
using fuzzy string matching and semantic similarity techniques.
"""

import pandas as pd
import numpy as np
from fuzzywuzzy import fuzz, process
import re
import csv
from collections import defaultdict
import json

def load_data():
    """Load the CSV files and return dataframes"""
    try:
        # Load Foursquare categories
        fsq_df = pd.read_csv('Foursquare Category Mapping.csv')
        
        # Load Overture Map categories - the file has a header but data is only in first column
        # Skip the header row and read just the first column
        om_df = pd.read_csv('OM Catgories.csv', usecols=[0], skiprows=1, names=['CATEGORY'])
        
        # Remove any NaN values
        om_df = om_df.dropna()
        
        # Load simplified categories for additional context
        om_simplified_df = pd.read_csv('OM_Categories_Simplified.csv')
        
        print(f"OM Categories columns: {om_df.columns.tolist()}")
        print(f"OM Categories shape: {om_df.shape}")
        print(f"First few OM categories: {om_df.head(5)['CATEGORY'].tolist()}")
        
        return fsq_df, om_df, om_simplified_df
    except Exception as e:
        print(f"Error loading data: {e}")
        return None, None, None

def preprocess_category_name(name):
    """Clean and normalize category names for better matching"""
    if pd.isna(name):
        return ""
    
    # Convert to lowercase
    name = str(name).lower()
    
    # Remove common prefixes/suffixes that might interfere with matching
    name = re.sub(r'^(the|a|an)\s+', '', name)
    name = re.sub(r'\s+(shop|store|restaurant|bar|club|center|centre)$', '', name)
    
    # Replace underscores and hyphens with spaces
    name = re.sub(r'[_-]', ' ', name)
    
    # Remove extra whitespace
    name = re.sub(r'\s+', ' ', name).strip()
    
    return name

def extract_keywords(category_name):
    """Extract meaningful keywords from category names"""
    # Common words to ignore
    stop_words = {'and', 'or', 'the', 'a', 'an', 'of', 'in', 'on', 'at', 'to', 'for', 'with', 'by'}
    
    words = preprocess_category_name(category_name).split()
    keywords = [word for word in words if word not in stop_words and len(word) > 2]
    
    return keywords

def calculate_semantic_similarity(om_category, fsq_category_name, fsq_category_label):
    """Calculate semantic similarity between categories"""
    om_clean = preprocess_category_name(om_category)
    fsq_name_clean = preprocess_category_name(fsq_category_name)
    fsq_label_clean = preprocess_category_name(fsq_category_label)
    
    # Calculate various similarity scores
    name_similarity = fuzz.ratio(om_clean, fsq_name_clean)
    label_similarity = fuzz.ratio(om_clean, fsq_label_clean)
    
    # Check for partial matches
    partial_name = fuzz.partial_ratio(om_clean, fsq_name_clean)
    partial_label = fuzz.partial_ratio(om_clean, fsq_label_clean)
    
    # Token-based matching (good for multi-word categories)
    token_name = fuzz.token_set_ratio(om_clean, fsq_name_clean)
    token_label = fuzz.token_set_ratio(om_clean, fsq_label_clean)
    
    # Keyword overlap scoring
    om_keywords = set(extract_keywords(om_category))
    fsq_keywords = set(extract_keywords(fsq_category_name) + extract_keywords(fsq_category_label))
    
    if om_keywords and fsq_keywords:
        keyword_overlap = len(om_keywords.intersection(fsq_keywords)) / len(om_keywords.union(fsq_keywords))
    else:
        keyword_overlap = 0
    
    # Weighted composite score
    composite_score = (
        name_similarity * 0.25 +
        label_similarity * 0.25 +
        partial_name * 0.15 +
        partial_label * 0.15 +
        token_name * 0.1 +
        token_label * 0.1 +
        keyword_overlap * 100 * 0.1  # Convert to 0-100 scale
    )
    
    return {
        'composite_score': composite_score,
        'name_similarity': name_similarity,
        'label_similarity': label_similarity,
        'partial_name': partial_name,
        'partial_label': partial_label,
        'token_name': token_name,
        'token_label': token_label,
        'keyword_overlap': keyword_overlap
    }

def find_best_matches(om_category, fsq_df, top_n=5):
    """Find the best matching Foursquare categories for an Overture Map category"""
    matches = []
    
    for _, fsq_row in fsq_df.iterrows():
        similarity_scores = calculate_semantic_similarity(
            om_category,
            fsq_row['Category Name'],
            fsq_row['Category Label']
        )
        
        match_info = {
            'fsq_category_id': fsq_row['Category ID'],
            'fsq_category_name': fsq_row['Category Name'],
            'fsq_category_label': fsq_row['Category Label'],
            'om_category': om_category,
            **similarity_scores
        }
        
        matches.append(match_info)
    
    # Sort by composite score descending
    matches.sort(key=lambda x: x['composite_score'], reverse=True)
    
    return matches[:top_n]

def create_manual_mappings():
    """Create manual mappings for categories that are difficult to match automatically"""
    manual_mappings = {
        # Restaurant categories
        'thai_restaurant': '4bf58dd8d48988d149941735',  # Thai Restaurant
        'chinese_restaurant': '4bf58dd8d48988d145941735',  # Chinese Restaurant
        'italian_restaurant': '4bf58dd8d48988d110941735',  # Italian Restaurant
        'mexican_restaurant': '4bf58dd8d48988d1c1941735',  # Mexican Restaurant
        'indian_restaurant': '4bf58dd8d48988d10f941735',  # Indian Restaurant
        'japanese_restaurant': '4bf58dd8d48988d111941735',  # Japanese Restaurant
        'french_restaurant': '4bf58dd8d48988d10c941735',  # French Restaurant
        'american_restaurant': '4bf58dd8d48988d14e941735',  # American Restaurant
        'korean_restaurant': '4bf58dd8d48988d113941735',  # Korean Restaurant
        'vietnamese_restaurant': '4bf58dd8d48988d14a941735',  # Vietnamese Restaurant
        'pizza_restaurant': '4bf58dd8d48988d1ca941735',  # Pizza Place
        'burger_restaurant': '4bf58dd8d48988d16c941735',  # Burger Joint
        'sandwich_shop': '4bf58dd8d48988d1c5941735',  # Sandwich Place
        'coffee_shop': '4bf58dd8d48988d1e0931735',  # Coffee Shop
        'bakery': '4bf58dd8d48988d16a941735',  # Bakery
        'bar': '4bf58dd8d48988d116941735',  # Bar
        'restaurant': '4bf58dd8d48988d1c4941735',  # Restaurant
        'fast_food_restaurant': '4bf58dd8d48988d16e941735',  # Fast Food Restaurant
        
        # Healthcare
        'general_dentistry': '4bf58dd8d48988d177941735',  # Dentist's Office
        'hospital': '4bf58dd8d48988d196941735',  # Hospital
        'pharmacy': '4bf58dd8d48988d10f951735',  # Pharmacy
        'doctor': '4bf58dd8d48988d177941735',  # Doctor's Office
        'dentist': '4bf58dd8d48988d177941735',  # Dentist's Office
        'veterinarian': '4bf58dd8d48988d100951735',  # Veterinarian
        'urgent_care_clinic': '4bf58dd8d48988d196941735',  # Medical Center
        
        # Retail
        'grocery_store': '4bf58dd8d48988d118951735',  # Grocery Store
        'convenience_store': '4bf58dd8d48988d1f6931735',  # Convenience Store
        'gas_station': '4bf58dd8d48988d113951735',  # Gas Station
        'supermarket': '4bf58dd8d48988d118951735',  # Grocery Store
        'department_store': '4bf58dd8d48988d1f7931735',  # Department Store
        'clothing_store': '4bf58dd8d48988d103951735',  # Clothing Store
        'shoe_store': '4bf58dd8d48988d107951735',  # Shoe Store
        'bookstore': '4bf58dd8d48988d114951735',  # Bookstore
        'hardware_store': '4bf58dd8d48988d112951735',  # Hardware Store
        'toy_store': '4bf58dd8d48988d1f3931735',  # Toy / Game Store
        
        # Entertainment
        'movie_theater': '4bf58dd8d48988d17f941735',  # Movie Theater
        'cinema': '4bf58dd8d48988d17f941735',  # Movie Theater
        'gym': '4bf58dd8d48988d175941735',  # Gym
        'museum': '4bf58dd8d48988d181941735',  # Museum
        'zoo': '4bf58dd8d48988d17b941735',  # Zoo
        'park': '4bf58dd8d48988d163941735',  # Park
        'library': '4bf58dd8d48988d12f941735',  # Library
        'casino': '4bf58dd8d48988d17c941735',  # Casino
        'bowling_alley': '4bf58dd8d48988d1e4931735',  # Bowling Alley
        
        # Transportation
        'airport': '4bf58dd8d48988d1ed931735',  # Airport
        'bus_station': '4bf58dd8d48988d1fe931735',  # Bus Station
        'train_station': '4bf58dd8d48988d129941735',  # Train Station
        'gas_station': '4bf58dd8d48988d113951735',  # Gas Station
        'parking': '4c38df4de52ce0d596b336e1',  # Parking
        
        # Services
        'bank': '4bf58dd8d48988d10a951735',  # Bank
        'atm': '4bf58dd8d48988d10b951735',  # ATM
        'post_office': '4bf58dd8d48988d172941735',  # Post Office
        'hotel': '4bf58dd8d48988d1fa931735',  # Hotel
        'school': '4bf58dd8d48988d13b941735',  # School
        'university': '4bf58dd8d48988d1ae941735',  # College & University
        
        # Add more manual mappings as needed
    }
    
    return manual_mappings

def map_categories():
    """Main function to map all Overture Map categories to Foursquare categories"""
    print("Loading data...")
    fsq_df, om_df, om_simplified_df = load_data()
    
    if fsq_df is None or om_df is None:
        print("Failed to load data. Please check file paths.")
        return
    
    print(f"Loaded {len(fsq_df)} Foursquare categories and {len(om_df)} Overture Map categories")
    
    # Get manual mappings
    manual_mappings = create_manual_mappings()
    
    # Results storage
    mapping_results = []
    
    print("Starting category mapping...")
    
    for idx, om_category in enumerate(om_df['CATEGORY']):
        if pd.isna(om_category):
            continue
            
        # Print progress every 100 categories
        if (idx + 1) % 100 == 0 or idx < 10:
            print(f"Processing {idx+1}/{len(om_df)}: {om_category}")
        
        # Check if we have a manual mapping first
        if om_category in manual_mappings:
            fsq_match = fsq_df[fsq_df['Category ID'] == manual_mappings[om_category]]
            if not fsq_match.empty:
                result = {
                    'om_category': om_category,
                    'fsq_category_id': fsq_match.iloc[0]['Category ID'],
                    'fsq_category_name': fsq_match.iloc[0]['Category Name'],
                    'fsq_category_label': fsq_match.iloc[0]['Category Label'],
                    'mapping_method': 'manual',
                    'confidence_score': 100.0
                }
                mapping_results.append(result)
                continue
        
        # Find best automatic matches
        best_matches = find_best_matches(om_category, fsq_df, top_n=1)
        
        if best_matches:
            best_match = best_matches[0]
            result = {
                'om_category': om_category,
                'fsq_category_id': best_match['fsq_category_id'],
                'fsq_category_name': best_match['fsq_category_name'],
                'fsq_category_label': best_match['fsq_category_label'],
                'mapping_method': 'automatic',
                'confidence_score': best_match['composite_score'],
                'name_similarity': best_match['name_similarity'],
                'label_similarity': best_match['label_similarity'],
                'keyword_overlap': best_match['keyword_overlap']
            }
            mapping_results.append(result)
    
    # Save results
    results_df = pd.DataFrame(mapping_results)
    results_df.to_csv('overture_to_foursquare_mapping.csv', index=False)
    
    # Create summary statistics
    print("\n=== MAPPING SUMMARY ===")
    print(f"Total categories mapped: {len(mapping_results)}")
    print(f"Manual mappings: {len([r for r in mapping_results if r['mapping_method'] == 'manual'])}")
    print(f"Automatic mappings: {len([r for r in mapping_results if r['mapping_method'] == 'automatic'])}")
    
    # Show confidence distribution
    auto_scores = [r['confidence_score'] for r in mapping_results if r['mapping_method'] == 'automatic']
    if auto_scores:
        print(f"Average confidence score: {np.mean(auto_scores):.2f}")
        print(f"High confidence (>80): {len([s for s in auto_scores if s > 80])}")
        print(f"Medium confidence (60-80): {len([s for s in auto_scores if 60 <= s <= 80])}")
        print(f"Low confidence (<60): {len([s for s in auto_scores if s < 60])}")
    
    # Show some examples
    print("\n=== TOP MATCHES (by confidence) ===")
    sorted_results = sorted([r for r in mapping_results if r['mapping_method'] == 'automatic'], 
                          key=lambda x: x['confidence_score'], reverse=True)
    
    for i, result in enumerate(sorted_results[:10]):
        print(f"{i+1}. {result['om_category']} -> {result['fsq_category_name']} ({result['confidence_score']:.1f})")
    
    print(f"\nResults saved to 'overture_to_foursquare_mapping.csv'")
    
    return results_df

if __name__ == "__main__":
    # Install required packages if not available
    try:
        import fuzzywuzzy
    except ImportError:
        print("Installing required packages...")
        import subprocess
        subprocess.check_call(['pip', 'install', 'fuzzywuzzy', 'python-levenshtein'])
    
    map_categories()