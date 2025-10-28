#!/usr/bin/env python3
"""
Script to map Overture Map POI categories to Foursquare POI categories.
Maps Category Label from OM Categories to Category Label from FSQ Categories.
"""

import pandas as pd
import re
from difflib import SequenceMatcher

def normalize_text(text):
    """Normalize text for better matching."""
    if pd.isna(text):
        return ""
    text = str(text).lower()
    text = text.replace('_', ' ')
    text = ' '.join(text.split())
    return text

def extract_keywords(text):
    """Extract meaningful keywords from text."""
    stop_words = {'and', 'or', 'the', 'a', 'an', 'in', 'of', 'for', 'to', 'with', 'at', 'by', 'from', 'on'}
    words = text.split()
    keywords = [w for w in words if w not in stop_words and len(w) > 2]
    return set(keywords)

def calculate_similarity(om_category, fsq_label):
    """Calculate similarity score between OM category and FSQ label."""
    om_norm = normalize_text(om_category)
    fsq_norm = normalize_text(fsq_label)
    
    # Direct string similarity
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
    
    # Weighted score
    final_score = (direct_similarity * 0.4 + keyword_overlap * 0.4 + containment_bonus * 0.2)
    
    return final_score

def find_best_matches(om_category, fsq_df, top_n=5):
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
            'FSQ_Category_ID': row['Category ID'],
            'FSQ_Category_Name': fsq_name,
            'FSQ_Category_Label': fsq_label,
            'Similarity_Score': best_score
        })
    
    # Sort by similarity score
    matches.sort(key=lambda x: x['Similarity_Score'], reverse=True)
    
    return matches[:top_n]

def main():
    print("="*70)
    print("Overture Map to Foursquare Category Mapping Tool")
    print("="*70)
    
    # Load Foursquare categories
    print("\n[1/4] Loading Foursquare Categories...")
    fsq_df = pd.read_csv('/workspace/Foursquare Category Mapping.csv')
    print(f"      ✓ Loaded {len(fsq_df)} Foursquare categories")
    
    # Load Overture Map categories
    print("\n[2/4] Loading Overture Map Categories...")
    om_df = pd.read_csv('/workspace/Overture Category Mapping.csv')
    print(f"      ✓ Loaded {len(om_df)} Overture Map categories")
    
    # Get unique categories
    om_categories = om_df['CATEGORY_PRIMARY'].dropna().unique()
    print(f"      ✓ Processing {len(om_categories)} unique OM categories")
    
    # Create mapping
    print(f"\n[3/4] Mapping categories (this may take a minute)...")
    results = []
    
    for i, om_cat in enumerate(om_categories):
        if (i + 1) % 200 == 0:
            print(f"      Progress: {i + 1}/{len(om_categories)} ({(i+1)/len(om_categories)*100:.1f}%)")
        
        # Find best matches
        top_matches = find_best_matches(om_cat, fsq_df, top_n=5)
        
        # Create result row
        result = {
            'OM_Category': om_cat,
            'Best_Match_FSQ_Category_Label': top_matches[0]['FSQ_Category_Label'],
            'Best_Match_FSQ_Category_Name': top_matches[0]['FSQ_Category_Name'],
            'Best_Match_FSQ_Category_ID': top_matches[0]['FSQ_Category_ID'],
            'Confidence_Score': round(top_matches[0]['Similarity_Score'], 2),
        }
        
        # Add alternative matches
        for j in range(1, 5):
            result[f'Alternative_{j}_FSQ_Label'] = top_matches[j]['FSQ_Category_Label']
            result[f'Alternative_{j}_Score'] = round(top_matches[j]['Similarity_Score'], 2)
        
        results.append(result)
    
    print(f"      ✓ Completed mapping all {len(om_categories)} categories")
    
    # Create output DataFrame
    output_df = pd.DataFrame(results)
    
    # Sort by OM category name for easier review
    output_df = output_df.sort_values('OM_Category')
    
    # Save to CSV
    print("\n[4/4] Saving results...")
    output_path = '/workspace/OM_FSQ_Category_Mapping_Results.csv'
    output_df.to_csv(output_path, index=False)
    print(f"      ✓ Saved to: {output_path}")
    
    # Print statistics
    print("\n" + "="*70)
    print("MAPPING STATISTICS")
    print("="*70)
    print(f"Total OM categories mapped:        {len(output_df)}")
    print(f"Average confidence score:          {output_df['Confidence_Score'].mean():.2f}")
    print(f"High confidence (>70):             {(output_df['Confidence_Score'] > 70).sum()} ({(output_df['Confidence_Score'] > 70).sum()/len(output_df)*100:.1f}%)")
    print(f"Medium confidence (50-70):         {((output_df['Confidence_Score'] >= 50) & (output_df['Confidence_Score'] <= 70)).sum()} ({((output_df['Confidence_Score'] >= 50) & (output_df['Confidence_Score'] <= 70)).sum()/len(output_df)*100:.1f}%)")
    print(f"Low confidence (<50):              {(output_df['Confidence_Score'] < 50).sum()} ({(output_df['Confidence_Score'] < 50).sum()/len(output_df)*100:.1f}%)")
    
    # Show sample mappings
    print("\n" + "="*70)
    print("SAMPLE HIGH CONFIDENCE MAPPINGS (Top 15)")
    print("="*70)
    high_conf = output_df.nlargest(15, 'Confidence_Score')[['OM_Category', 'Best_Match_FSQ_Category_Label', 'Confidence_Score']]
    for idx, row in high_conf.iterrows():
        print(f"{row['OM_Category']:35s} → {row['Best_Match_FSQ_Category_Label']:50s} [{row['Confidence_Score']:.1f}]")
    
    print("\n" + "="*70)
    print("SAMPLE LOW CONFIDENCE MAPPINGS (Bottom 15 - May Need Review)")
    print("="*70)
    low_conf = output_df.nsmallest(15, 'Confidence_Score')[['OM_Category', 'Best_Match_FSQ_Category_Label', 'Confidence_Score']]
    for idx, row in low_conf.iterrows():
        print(f"{row['OM_Category']:35s} → {row['Best_Match_FSQ_Category_Label']:50s} [{row['Confidence_Score']:.1f}]")
    
    print("\n" + "="*70)
    print("✓ Mapping complete! Review the output file for full results.")
    print("="*70)

if __name__ == "__main__":
    main()
