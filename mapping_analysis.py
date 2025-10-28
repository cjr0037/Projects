#!/usr/bin/env python3
"""
Analysis script for the Overture Map to Foursquare category mapping results
"""

import pandas as pd
import numpy as np
from collections import Counter

def analyze_mapping_results():
    """Analyze the mapping results and create summary statistics"""
    
    # Load the results
    results_df = pd.read_csv('overture_to_foursquare_mapping.csv')
    
    print("=== OVERTURE MAP TO FOURSQUARE CATEGORY MAPPING ANALYSIS ===\n")
    
    # Basic statistics
    total_mappings = len(results_df)
    manual_mappings = len(results_df[results_df['mapping_method'] == 'manual'])
    automatic_mappings = len(results_df[results_df['mapping_method'] == 'automatic'])
    
    print(f"Total categories mapped: {total_mappings:,}")
    print(f"Manual mappings: {manual_mappings:,} ({manual_mappings/total_mappings*100:.1f}%)")
    print(f"Automatic mappings: {automatic_mappings:,} ({automatic_mappings/total_mappings*100:.1f}%)")
    
    # Confidence score analysis for automatic mappings
    auto_results = results_df[results_df['mapping_method'] == 'automatic']
    if len(auto_results) > 0:
        avg_confidence = auto_results['confidence_score'].mean()
        median_confidence = auto_results['confidence_score'].median()
        
        high_confidence = len(auto_results[auto_results['confidence_score'] > 80])
        medium_confidence = len(auto_results[(auto_results['confidence_score'] >= 60) & (auto_results['confidence_score'] <= 80)])
        low_confidence = len(auto_results[auto_results['confidence_score'] < 60])
        
        print(f"\n=== CONFIDENCE SCORE ANALYSIS (Automatic Mappings) ===")
        print(f"Average confidence score: {avg_confidence:.2f}")
        print(f"Median confidence score: {median_confidence:.2f}")
        print(f"High confidence (>80): {high_confidence:,} ({high_confidence/automatic_mappings*100:.1f}%)")
        print(f"Medium confidence (60-80): {medium_confidence:,} ({medium_confidence/automatic_mappings*100:.1f}%)")
        print(f"Low confidence (<60): {low_confidence:,} ({low_confidence/automatic_mappings*100:.1f}%)")
    
    # Top-level Foursquare category distribution
    print(f"\n=== TOP-LEVEL FOURSQUARE CATEGORY DISTRIBUTION ===")
    
    # Extract top-level categories from the hierarchical labels
    def extract_top_level_category(label):
        if pd.isna(label):
            return "Unknown"
        return label.split(' > ')[0]
    
    results_df['fsq_top_level'] = results_df['fsq_category_label'].apply(extract_top_level_category)
    top_level_counts = results_df['fsq_top_level'].value_counts()
    
    for category, count in top_level_counts.head(10).items():
        print(f"{category}: {count:,} ({count/total_mappings*100:.1f}%)")
    
    # Show some examples of high-confidence matches
    print(f"\n=== HIGH-CONFIDENCE AUTOMATIC MAPPINGS (Score > 90) ===")
    high_conf_auto = auto_results[auto_results['confidence_score'] > 90].sort_values('confidence_score', ascending=False)
    
    for idx, row in high_conf_auto.head(15).iterrows():
        print(f"{row['om_category']} -> {row['fsq_category_name']} ({row['confidence_score']:.1f})")
    
    # Show some examples of low-confidence matches that might need review
    print(f"\n=== LOW-CONFIDENCE MAPPINGS (Score < 50) - May Need Review ===")
    low_conf_auto = auto_results[auto_results['confidence_score'] < 50].sort_values('confidence_score', ascending=True)
    
    for idx, row in low_conf_auto.head(10).iterrows():
        print(f"{row['om_category']} -> {row['fsq_category_name']} ({row['confidence_score']:.1f})")
    
    # Create a simplified mapping file for easy reference
    simplified_df = results_df[['om_category', 'fsq_category_name', 'fsq_category_label', 'confidence_score']].copy()
    simplified_df['confidence_score'] = simplified_df['confidence_score'].round(1)
    simplified_df = simplified_df.sort_values(['confidence_score'], ascending=False)
    
    simplified_df.to_csv('overture_to_foursquare_mapping_simplified.csv', index=False)
    print(f"\n=== FILES CREATED ===")
    print("1. overture_to_foursquare_mapping.csv - Complete mapping with all metrics")
    print("2. overture_to_foursquare_mapping_simplified.csv - Simplified version for easy reference")
    
    # Category-specific analysis
    print(f"\n=== CATEGORY-SPECIFIC INSIGHTS ===")
    
    # Restaurant categories
    restaurant_categories = results_df[results_df['om_category'].str.contains('restaurant', case=False)]
    print(f"Restaurant categories mapped: {len(restaurant_categories)}")
    
    # Healthcare categories  
    healthcare_keywords = ['medical', 'health', 'doctor', 'hospital', 'clinic', 'dentist', 'pharmacy']
    healthcare_categories = results_df[results_df['om_category'].str.contains('|'.join(healthcare_keywords), case=False)]
    print(f"Healthcare categories mapped: {len(healthcare_categories)}")
    
    # Retail categories
    retail_keywords = ['store', 'shop', 'retail', 'market', 'grocery']
    retail_categories = results_df[results_df['om_category'].str.contains('|'.join(retail_keywords), case=False)]
    print(f"Retail categories mapped: {len(retail_categories)}")
    
    return results_df

if __name__ == "__main__":
    analyze_mapping_results()