#!/usr/bin/env python3
"""
Master Category Mapping Tool
Creates a comprehensive mapping between Foursquare Places categories (dominant) 
and Overture Mapping Places categories using semantic analysis.
"""

import pandas as pd
import numpy as np
from difflib import SequenceMatcher
import re
from collections import defaultdict
import json

class CategoryMapper:
    def __init__(self):
        self.foursquare_data = None
        self.overture_data = None
        self.mapping_results = []
        
        # Define semantic category groups for intelligent matching
        self.semantic_groups = {
            'food_dining': {
                'keywords': ['restaurant', 'cafe', 'bar', 'food', 'dining', 'bakery', 'diner', 
                           'eatery', 'bistro', 'grill', 'kitchen', 'cuisine', 'pizza', 'burger',
                           'sandwich', 'coffee', 'tea', 'brewery', 'pub', 'tavern', 'steakhouse'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'retail_shopping': {
                'keywords': ['store', 'shop', 'retail', 'market', 'boutique', 'mall', 'outlet',
                           'vendor', 'dealer', 'supplier', 'wholesaler', 'shopping'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'healthcare_medical': {
                'keywords': ['hospital', 'clinic', 'medical', 'doctor', 'dentist', 'pharmacy',
                           'health', 'physician', 'surgeon', 'therapy', 'treatment', 'care'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'entertainment_recreation': {
                'keywords': ['entertainment', 'recreation', 'sports', 'fitness', 'gym', 'park',
                           'theater', 'cinema', 'museum', 'club', 'center', 'venue', 'stadium'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'services_professional': {
                'keywords': ['service', 'agency', 'office', 'professional', 'consulting', 
                           'repair', 'maintenance', 'cleaning', 'legal', 'financial'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'transportation': {
                'keywords': ['transport', 'station', 'airport', 'parking', 'rental', 'taxi',
                           'bus', 'train', 'subway', 'ferry', 'automotive', 'gas'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'accommodation_lodging': {
                'keywords': ['hotel', 'motel', 'lodge', 'inn', 'resort', 'accommodation',
                           'hostel', 'bed', 'breakfast'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'education_institutions': {
                'keywords': ['school', 'university', 'college', 'education', 'academy',
                           'institute', 'learning', 'training', 'library'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'government_public': {
                'keywords': ['government', 'public', 'municipal', 'federal', 'state', 'city',
                           'hall', 'office', 'department', 'agency', 'court'],
                'foursquare_categories': [],
                'overture_categories': []
            },
            'religious_spiritual': {
                'keywords': ['church', 'temple', 'mosque', 'synagogue', 'religious', 'spiritual',
                           'cathedral', 'chapel', 'worship'],
                'foursquare_categories': [],
                'overture_categories': []
            }
        }

    def load_data(self):
        """Load both CSV files"""
        print("Loading Foursquare categories...")
        self.foursquare_data = pd.read_csv('/workspace/Foursquare Category Mapping.csv')
        print(f"Loaded {len(self.foursquare_data)} Foursquare categories")
        
        print("Loading Overture categories...")
        self.overture_data = pd.read_csv('/workspace/Overture Category Mapping.csv')
        print(f"Loaded {len(self.overture_data)} Overture categories")
        
        # Clean and prepare data
        self.foursquare_data['Category Name'] = self.foursquare_data['Category Name'].str.strip()
        self.foursquare_data['Category Label'] = self.foursquare_data['Category Label'].str.strip()
        self.overture_data['CATEGORY_PRIMARY'] = self.overture_data['CATEGORY_PRIMARY'].str.strip()

    def normalize_text(self, text):
        """Normalize text for better matching"""
        if pd.isna(text):
            return ""
        
        # Convert to lowercase
        text = str(text).lower()
        
        # Replace common variations
        replacements = {
            '&': 'and',
            '+': 'and',
            '/': ' ',
            '-': ' ',
            '_': ' ',
            '  ': ' '
        }
        
        for old, new in replacements.items():
            text = text.replace(old, new)
        
        # Remove special characters except spaces
        text = re.sub(r'[^\w\s]', '', text)
        
        # Remove extra spaces
        text = ' '.join(text.split())
        
        return text

    def calculate_similarity_score(self, text1, text2):
        """Calculate similarity score between two texts using multiple methods"""
        if not text1 or not text2:
            return 0.0
            
        # Normalize both texts
        norm_text1 = self.normalize_text(text1)
        norm_text2 = self.normalize_text(text2)
        
        # Exact match
        if norm_text1 == norm_text2:
            return 1.0
        
        # Sequence matcher similarity
        seq_similarity = SequenceMatcher(None, norm_text1, norm_text2).ratio()
        
        # Word overlap similarity
        words1 = set(norm_text1.split())
        words2 = set(norm_text2.split())
        
        if len(words1) == 0 and len(words2) == 0:
            word_similarity = 0.0
        else:
            intersection = words1.intersection(words2)
            union = words1.union(words2)
            word_similarity = len(intersection) / len(union) if len(union) > 0 else 0.0
        
        # Substring containment bonus
        containment_bonus = 0.0
        if norm_text1 in norm_text2 or norm_text2 in norm_text1:
            containment_bonus = 0.2
        
        # Combined score
        final_score = (seq_similarity * 0.4 + word_similarity * 0.5 + containment_bonus)
        
        return min(final_score, 1.0)

    def categorize_by_semantics(self):
        """Categorize entries into semantic groups"""
        print("Categorizing entries by semantic groups...")
        
        # Process Foursquare categories
        for idx, row in self.foursquare_data.iterrows():
            category_name = self.normalize_text(row['Category Name'])
            category_label = self.normalize_text(row['Category Label'])
            full_text = f"{category_name} {category_label}"
            
            for group_name, group_data in self.semantic_groups.items():
                for keyword in group_data['keywords']:
                    if keyword in full_text:
                        group_data['foursquare_categories'].append({
                            'index': idx,
                            'id': row['Category ID'],
                            'name': row['Category Name'],
                            'label': row['Category Label'],
                            'normalized': full_text
                        })
                        break
        
        # Process Overture categories
        for idx, row in self.overture_data.iterrows():
            category_name = self.normalize_text(row['CATEGORY_PRIMARY'])
            
            for group_name, group_data in self.semantic_groups.items():
                for keyword in group_data['keywords']:
                    if keyword in category_name:
                        group_data['overture_categories'].append({
                            'index': idx,
                            'name': row['CATEGORY_PRIMARY'],
                            'normalized': category_name
                        })
                        break

    def find_best_matches(self):
        """Find best matches between Foursquare and Overture categories"""
        print("Finding best matches between category systems...")
        
        # Track matched Overture categories to avoid duplicates
        matched_overture = set()
        
        # First, try semantic group matching
        for group_name, group_data in self.semantic_groups.items():
            print(f"Processing semantic group: {group_name}")
            
            for fs_cat in group_data['foursquare_categories']:
                best_match = None
                best_score = 0.0
                
                for ov_cat in group_data['overture_categories']:
                    if ov_cat['index'] in matched_overture:
                        continue
                        
                    score = self.calculate_similarity_score(fs_cat['name'], ov_cat['name'])
                    
                    if score > best_score and score >= 0.3:  # Minimum threshold
                        best_score = score
                        best_match = ov_cat
                
                if best_match:
                    matched_overture.add(best_match['index'])
                    self.mapping_results.append({
                        'foursquare_id': fs_cat['id'],
                        'foursquare_name': fs_cat['name'],
                        'foursquare_label': fs_cat['label'],
                        'overture_category': best_match['name'],
                        'similarity_score': best_score,
                        'match_type': 'semantic_group',
                        'semantic_group': group_name
                    })
        
        # Second, try direct matching for remaining categories
        print("Processing remaining categories with direct matching...")
        
        # Get unmatched Foursquare categories
        matched_fs_ids = {result['foursquare_id'] for result in self.mapping_results}
        unmatched_fs = self.foursquare_data[~self.foursquare_data['Category ID'].isin(matched_fs_ids)]
        
        # Get unmatched Overture categories
        unmatched_ov = self.overture_data[~self.overture_data.index.isin(matched_overture)]
        
        for idx, fs_row in unmatched_fs.iterrows():
            best_match = None
            best_score = 0.0
            best_ov_idx = None
            
            for ov_idx, ov_row in unmatched_ov.iterrows():
                if ov_idx in matched_overture:
                    continue
                
                # Try matching with category name
                score1 = self.calculate_similarity_score(fs_row['Category Name'], ov_row['CATEGORY_PRIMARY'])
                
                # Try matching with category label (last part)
                label_parts = fs_row['Category Label'].split(' > ')
                last_label = label_parts[-1] if label_parts else fs_row['Category Label']
                score2 = self.calculate_similarity_score(last_label, ov_row['CATEGORY_PRIMARY'])
                
                score = max(score1, score2)
                
                if score > best_score and score >= 0.4:  # Higher threshold for direct matching
                    best_score = score
                    best_match = ov_row
                    best_ov_idx = ov_idx
            
            if best_match is not None:
                matched_overture.add(best_ov_idx)
                self.mapping_results.append({
                    'foursquare_id': fs_row['Category ID'],
                    'foursquare_name': fs_row['Category Name'],
                    'foursquare_label': fs_row['Category Label'],
                    'overture_category': best_match['CATEGORY_PRIMARY'],
                    'similarity_score': best_score,
                    'match_type': 'direct_match',
                    'semantic_group': 'none'
                })
        
        # Add unmatched Foursquare categories
        final_matched_fs_ids = {result['foursquare_id'] for result in self.mapping_results}
        for idx, fs_row in self.foursquare_data.iterrows():
            if fs_row['Category ID'] not in final_matched_fs_ids:
                self.mapping_results.append({
                    'foursquare_id': fs_row['Category ID'],
                    'foursquare_name': fs_row['Category Name'],
                    'foursquare_label': fs_row['Category Label'],
                    'overture_category': None,
                    'similarity_score': 0.0,
                    'match_type': 'no_match',
                    'semantic_group': 'none'
                })

    def generate_master_table(self):
        """Generate the final master category mapping table"""
        print("Generating master category mapping table...")
        
        # Convert results to DataFrame
        master_df = pd.DataFrame(self.mapping_results)
        
        # Sort by Foursquare category label for better organization
        master_df = master_df.sort_values('foursquare_label')
        
        # Add additional columns for analysis
        master_df['has_overture_match'] = master_df['overture_category'].notna()
        master_df['match_quality'] = pd.cut(master_df['similarity_score'], 
                                          bins=[0, 0.3, 0.6, 0.8, 1.0], 
                                          labels=['Poor', 'Fair', 'Good', 'Excellent'])
        
        # Save to CSV
        output_file = '/workspace/Master_Category_Mapping.csv'
        master_df.to_csv(output_file, index=False)
        print(f"Master mapping table saved to: {output_file}")
        
        # Generate summary statistics
        self.generate_summary_report(master_df)
        
        return master_df

    def generate_summary_report(self, master_df):
        """Generate a summary report of the mapping results"""
        print("\n" + "="*60)
        print("MASTER CATEGORY MAPPING SUMMARY REPORT")
        print("="*60)
        
        total_fs = len(master_df)
        matched = len(master_df[master_df['has_overture_match']])
        unmatched = total_fs - matched
        
        print(f"Total Foursquare Categories: {total_fs}")
        print(f"Successfully Matched: {matched} ({matched/total_fs*100:.1f}%)")
        print(f"Unmatched: {unmatched} ({unmatched/total_fs*100:.1f}%)")
        
        print("\nMatch Quality Distribution:")
        quality_dist = master_df['match_quality'].value_counts().sort_index()
        for quality, count in quality_dist.items():
            print(f"  {quality}: {count} ({count/total_fs*100:.1f}%)")
        
        print("\nMatch Type Distribution:")
        type_dist = master_df['match_type'].value_counts()
        for match_type, count in type_dist.items():
            print(f"  {match_type}: {count} ({count/total_fs*100:.1f}%)")
        
        print("\nSemantic Group Distribution (for matched categories):")
        semantic_dist = master_df[master_df['has_overture_match']]['semantic_group'].value_counts()
        for group, count in semantic_dist.items():
            if group != 'none':
                print(f"  {group}: {count}")
        
        # Save detailed report
        report_file = '/workspace/Mapping_Summary_Report.txt'
        with open(report_file, 'w') as f:
            f.write("MASTER CATEGORY MAPPING SUMMARY REPORT\n")
            f.write("="*60 + "\n\n")
            f.write(f"Total Foursquare Categories: {total_fs}\n")
            f.write(f"Successfully Matched: {matched} ({matched/total_fs*100:.1f}%)\n")
            f.write(f"Unmatched: {unmatched} ({unmatched/total_fs*100:.1f}%)\n\n")
            
            f.write("Match Quality Distribution:\n")
            for quality, count in quality_dist.items():
                f.write(f"  {quality}: {count} ({count/total_fs*100:.1f}%)\n")
            
            f.write("\nMatch Type Distribution:\n")
            for match_type, count in type_dist.items():
                f.write(f"  {match_type}: {count} ({count/total_fs*100:.1f}%)\n")
                
            f.write("\nTop 20 Best Matches (by similarity score):\n")
            top_matches = master_df[master_df['has_overture_match']].nlargest(20, 'similarity_score')
            for idx, row in top_matches.iterrows():
                f.write(f"  {row['foursquare_name']} -> {row['overture_category']} (Score: {row['similarity_score']:.3f})\n")
        
        print(f"\nDetailed report saved to: {report_file}")

    def run_mapping_process(self):
        """Run the complete mapping process"""
        print("Starting Master Category Mapping Process...")
        print("="*60)
        
        self.load_data()
        self.categorize_by_semantics()
        self.find_best_matches()
        master_df = self.generate_master_table()
        
        print("\nMapping process completed successfully!")
        return master_df


if __name__ == "__main__":
    mapper = CategoryMapper()
    result = mapper.run_mapping_process()