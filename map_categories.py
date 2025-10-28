#!/usr/bin/env python3
"""
Script to map Overture Map POI categories to Foursquare POI categories
using text similarity matching.
"""

import pandas as pd
import re
from difflib import SequenceMatcher
from collections import defaultdict

def normalize_text(text):
    """Normalize text for better matching."""
    if pd.isna(text):
        return ""
    # Convert to lowercase
    text = str(text).lower()
    # Replace underscores with spaces
    text = text.replace('_', ' ')
    # Remove extra whitespace
    text = ' '.join(text.split())
    return text

def extract_keywords(text):
    """Extract meaningful keywords from text."""
    # Remove common connector words
    stop_words = {'and', 'or', 'the', 'a', 'an', 'in', 'of', 'for', 'to', 'with', 'at', 'by', 'from'}
    words = text.split()
    keywords = [w for w in words if w not in stop_words and len(w) > 1]
    return set(keywords)

def calculate_similarity(om_category, fsq_label):
    """Calculate similarity score between OM category and FSQ label."""
    om_norm = normalize_text(om_category)
    fsq_norm = normalize_text(fsq_label)
    
    # Direct string similarity (0-100)
    direct_similarity = SequenceMatcher(None, om_norm, fsq_norm).ratio() * 100
    
    # Keyword overlap similarity
    om_keywords = extract_keywords(om_norm)
    fsq_keywords = extract_keywords(fsq_norm)
    
    if om_keywords and fsq_keywords:
        keyword_overlap = len(om_keywords & fsq_keywords) / len(om_keywords) * 100
    else:
        keyword_overlap = 0
    
    # Check if OM category is contained in FSQ label
    containment_bonus = 0
    if om_norm in fsq_norm:
        containment_bonus = 30
    elif any(word in fsq_norm for word in om_keywords if len(word) > 3):
        containment_bonus = 15
    
    # Weighted average
    final_score = (direct_similarity * 0.4 + keyword_overlap * 0.4 + containment_bonus * 0.2)
    
    return final_score

def find_best_matches(om_category, fsq_df, top_n=3):
    """Find the top N best matching FSQ categories for an OM category."""
    matches = []
    
    for idx, row in fsq_df.iterrows():
        fsq_label = row['Category Label']
        fsq_name = row['Category Name']
        
        # Calculate similarity against both the full label and just the name
        label_score = calculate_similarity(om_category, fsq_label)
        name_score = calculate_similarity(om_category, fsq_name)
        
        # Use the higher score
        best_score = max(label_score, name_score)
        
        matches.append({
            'category_id': row['Category ID'],
            'category_name': fsq_name,
            'category_label': fsq_label,
            'similarity_score': best_score
        })
    
    # Sort by similarity score
    matches.sort(key=lambda x: x['similarity_score'], reverse=True)
    
    return matches[:top_n]

def main():
    print("Loading CSV files...")
    
    # Load Foursquare categories
    fsq_df = pd.read_csv('/workspace/Foursquare Category Mapping.csv')
    print(f"Loaded {len(fsq_df)} Foursquare categories")
    
    # Load Overture Map categories
    om_df = pd.read_csv('/workspace/Overture Category Mapping.csv')
    print(f"Loaded {len(om_df)} Overture Map categories")
    
    # Remove duplicates from OM categories
    om_categories = om_df['CATEGORY_PRIMARY'].dropna().unique()
    print(f"Processing {len(om_categories)} unique Overture Map categories")
    
    # Create mapping
    print("\nMapping categories...")
    results = []
    
    for i, om_cat in enumerate(om_categories):
        if (i + 1) % 100 == 0:
            print(f"Progress: {i + 1}/{len(om_categories)}")
        
        # Find best matches
        top_matches = find_best_matches(om_cat, fsq_df, top_n=3)
        
        # Store all three matches
        result = {
            'OM_Category': om_cat,
            'FSQ_Category_ID_1': top_matches[0]['category_id'],
            'FSQ_Category_Name_1': top_matches[0]['category_name'],
            'FSQ_Category_Label_1': top_matches[0]['category_label'],
            'Similarity_Score_1': round(top_matches[0]['similarity_score'], 2),
            'FSQ_Category_ID_2': top_matches[1]['category_id'],
            'FSQ_Category_Name_2': top_matches[1]['category_name'],
            'FSQ_Category_Label_2': top_matches[1]['category_label'],
            'Similarity_Score_2': round(top_matches[1]['similarity_score'], 2),
            'FSQ_Category_ID_3': top_matches[2]['category_id'],
            'FSQ_Category_Name_3': top_matches[2]['category_name'],
            'FSQ_Category_Label_3': top_matches[2]['category_label'],
            'Similarity_Score_3': round(top_matches[2]['similarity_score'], 2),
        }
        
        results.append(result)
    
    # Create output DataFrame
    output_df = pd.DataFrame(results)
    
    # Save to CSV
    output_path = '/workspace/OM_to_FSQ_Category_Mapping.csv'
    output_df.to_csv(output_path, index=False)
    print(f"\nMapping complete! Saved to: {output_path}")
    
    # Print statistics
    print(f"\nStatistics:")
    print(f"Total mappings: {len(output_df)}")
    print(f"Average top match score: {output_df['Similarity_Score_1'].mean():.2f}")
    print(f"Mappings with score > 70: {(output_df['Similarity_Score_1'] > 70).sum()}")
    print(f"Mappings with score > 50: {(output_df['Similarity_Score_1'] > 50).sum()}")
    print(f"Mappings with score < 30: {(output_df['Similarity_Score_1'] < 30).sum()}")
    
    # Show some sample mappings
    print("\n=== Sample High Confidence Mappings ===")
    high_conf = output_df.nlargest(10, 'Similarity_Score_1')[['OM_Category', 'FSQ_Category_Label_1', 'Similarity_Score_1']]
    print(high_conf.to_string(index=False))
    
    print("\n=== Sample Low Confidence Mappings (May Need Manual Review) ===")
    low_conf = output_df.nsmallest(10, 'Similarity_Score_1')[['OM_Category', 'FSQ_Category_Label_1', 'Similarity_Score_1']]
    print(low_conf.to_string(index=False))

if __name__ == "__main__":
    main()
