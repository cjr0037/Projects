#!/usr/bin/env python3
"""
Overture Maps Category Simplification Script

This script reads the Overture Maps categories CSV file and adds a simplified
taxonomy column by mapping granular categories to broader high-level categories.

Usage:
    python simplify_overture_categories.py
"""

import csv

def get_simplified_category(category):
    """
    Map a granular Overture Maps category to a simplified high-level category.
    
    Args:
        category (str): The original category label
        
    Returns:
        str: The simplified category name
    """
    cat = category.lower()
    
    # Food & Dining
    if any(x in cat for x in ['restaurant', 'cafe', 'coffee', 'food', 'dining', 'bar', 'pub', 'brewery', 'winery', 
                               'bakery', 'pizza', 'burger', 'sandwich', 'diner', 'bistro', 'eatery', 'caterer',
                               'donuts', 'ice_cream', 'dessert', 'candy', 'chocolate', 'patisserie', 'bagel',
                               'taco', 'barbecue', 'steakhouse', 'gastropub', 'brasserie', 'lounge', '_bar',
                               'cocktail', 'wine_bar', 'beer_bar', 'speakeasy', 'champagne_bar', 'sake_bar',
                               'hookah', 'cigar_bar', 'tea_room', 'juice_bar', 'smoothie', 'meat_shop', 'butcher',
                               'seafood', 'delicatessen', 'cheese_shop', 'pasta_shop', 'pie_shop', 'cupcake',
                               'empanadas', 'pretzel', 'popcorn', 'hot_dog', 'chicken_wings', 'poke', 'doner',
                               'falafel', 'dumpling', 'noodles', 'sushi', 'dim_sum', 'waffle', 'pancake',
                               'gelato', 'frozen_yoghurt', 'shaved_ice', 'acai', 'kombucha', 'bubble_tea',
                               'cidery', 'distillery', 'eat_and_drink', 'tapas', 'gastropub']):
        return 'Food & Dining'
    
    # Healthcare & Medical
    if any(x in cat for x in ['doctor', 'physician', 'medical', 'health', 'clinic', 'hospital', 'dentist', 'dental',
                               'surgeon', 'surgery', 'therapist', 'therapy', 'chiropractor', 'acupuncture',
                               'optometrist', 'ophthalmologist', 'podiatrist', 'dermatologist', 'cardiologist',
                               'neurologist', 'oncologist', 'pediatric', 'obstetrician', 'gynecologist',
                               'urologist', 'radiologist', 'anesthesiologist', 'pathologist', 'psychiatrist',
                               'psychologist', 'counselor', 'psychotherapist', 'pharmacy', 'medicine',
                               'veterinarian', 'veterinary', 'animal_hospital', 'emergency_room', 'urgent_care',
                               'rehabilitation', 'hospice', 'nursing', 'dialysis', 'orthopedist', 'allergist',
                               'endocrinologist', 'gastroenterologist', 'nephrologist', 'pulmonologist',
                               'rheumatologist', 'hematology', 'hepatologist', 'proctologist', 'toxicologist',
                               'immunologist', 'geneticist', 'retina_specialist', 'otologist', 'audiologist',
                               'speech_therapist', 'occupational_therapy', 'physical_therapy', 'massage_therapy',
                               'naturopathic', 'holistic', 'alternative_medicine', 'homeopathic', 'ayurveda',
                               'acne_treatment', 'laser_eye', 'cannabis_clinic', 'fertility', 'midwife',
                               'doula', 'maternity', 'prenatal', 'lactation', 'abortion', 'mohel']):
        return 'Healthcare & Medical'
    
    # Retail & Shopping
    if any(x in cat for x in ['store', 'shop', 'retail', 'boutique', 'market', 'supermarket', 'grocery',
                               'department_store', 'discount_store', 'outlet', 'thrift', 'pawn',
                               'convenience_store', 'drugstore', 'mall', 'shopping_center',
                               'bookstore', 'toy_store', 'gift_shop', 'souvenir', 'clothing', 'apparel',
                               'shoe_store', 'jewelry_store', 'watch_store', 'eyewear', 'optical',
                               'furniture_store', 'home_goods', 'hardware_store', 'paint_store',
                               'flooring_store', 'carpet_store', 'tile_store', 'lighting_store',
                               'appliance_store', 'electronics', 'computer_store', 'mobile_phone_store',
                               'sporting_goods', 'outdoor_gear', 'bike_shop', 'surf_shop', 'dive_shop',
                               'gun_and_ammo', 'pet_store', 'aquatic_pet', 'bird_shop', 'reptile_shop',
                               'art_supply', 'craft_shop', 'fabric_store', 'knitting', 'yarn',
                               'music_store', 'instrument_store', 'vinyl_record', 'video_game_store',
                               'comic_books', 'antique', 'vintage', 'flea_market', 'farmers_market',
                               'shopping', 'superstore', 'kiosk', 'dispensary', 'liquor_store',
                               'tobacco_shop', 'vape', 'e_cigarette']):
        return 'Retail & Shopping'
    
    # Automotive
    if any(x in cat for x in ['auto', 'automotive', 'car_', 'vehicle', 'truck_', 'motorcycle', 'scooter_dealer',
                               'dealer', 'repair', 'mechanic', 'tire', 'brake', 'transmission', 'muffler',
                               'body_shop', 'detailing', 'car_wash', 'towing', 'gas_station', 'fuel_',
                               'oil_change', 'smog', 'inspection', 'emissions', 'windshield', 'window_tint',
                               'upholstery', 'customization', 'restoration']):
        if 'museum' not in cat:
            return 'Automotive'
    
    # Beauty & Wellness
    if any(x in cat for x in ['salon', 'barber', 'hair_', 'nail_', 'spa', 'beauty', 'esthetician', 'aesthetician',
                               'massage', 'facial', 'wax', 'laser_hair', 'eyelash', 'eyebrow', 'tanning',
                               'tattoo', 'piercing', 'makeup', 'cosmetic', 'skin_care', 'aromatherapy',
                               'reiki', 'halotherapy', 'cryotherapy', 'hydrotherapy', 'float_spa', 'sauna',
                               'fitness', 'gym', 'yoga', 'pilates', 'boxing', 'martial_arts', 'karate',
                               'taekwondo', 'jiu_jitsu', 'muay_thai', 'kickboxing', 'boot_camp',
                               'trainer', 'weight_loss', 'nutrition', 'dietitian', 'health_coach',
                               'blow_dry', 'threading', 'sugaring', 'boudoir']):
        if 'supply' not in cat and 'school' not in cat and 'product' not in cat and 'manufacturer' not in cat:
            return 'Beauty & Wellness'
    
    # Sports & Recreation
    if any(x in cat for x in ['sports', 'stadium', 'arena', 'field', 'court', 'track', 'pitch',
                               'golf', 'bowling', 'skating', 'ski_', 'climbing', 'swimming_pool',
                               'tennis', 'basketball', 'football', 'soccer', 'baseball', 'hockey',
                               'volleyball', 'rugby', 'cricket', 'squash', 'racquetball', 'handball',
                               'badminton', 'table_tennis', 'bocce', 'disc_golf', 'mini_golf',
                               'go_kart', 'race_track', 'shooting_range', 'archery', 'paintball',
                               'laser_tag', 'trampoline', 'bounce_house', 'batting_cage',
                               'skate_park', 'bmx', 'mountain_bike', 'trail', 'hiking',
                               'scuba', 'diving', 'snorkel', 'surf', 'kite', 'paddle', 'kayak',
                               'canoe', 'sailing', 'rowing', 'fishing', 'hunting', 'horse_', 'equestrian',
                               'ski_resort', 'tubing', 'sledding', 'snowboard', 'ice_rink',
                               'gym', 'fitness', 'aerial', 'rock_climbing', 'bouldering']):
        if 'museum' not in cat and 'store' not in cat and 'equipment' not in cat:
            return 'Sports & Recreation'
    
    # Arts & Entertainment
    if any(x in cat for x in ['museum', 'gallery', 'theater', 'theatre', 'cinema', 'movie', 'performing_arts',
                               'concert', 'music_venue', 'comedy', 'nightclub', 'dance_club',
                               'amusement', 'theme_park', 'water_park', 'zoo', 'aquarium', 'botanical',
                               'casino', 'arcade', 'escape_room', 'virtual_reality',
                               'festival', 'fair', 'carnival', 'circus', 'rodeo', 'haunted_house',
                               'observatory', 'planetarium', 'artist', 'art_', 'cultural_center',
                               'karaoke', 'bingo', 'magic', 'clown', 'entertainment', 'production',
                               'studio', 'recording', 'rehearsal', 'band', 'orchestra', 'choir',
                               'opera', 'ballet', 'dance_school', 'drama', 'acting']):
        return 'Arts & Entertainment'
    
    # Education
    if any(x in cat for x in ['school', 'university', 'college', 'education', 'academy', 'institute',
                               'kindergarten', 'preschool', 'day_care', 'daycare', 'elementary',
                               'middle_school', 'high_school', 'tutoring', 'training', 'class',
                               'lesson', 'instructor', 'teacher', 'coach', 'library', 'student_union',
                               'montessori', 'waldorf', 'charter_school', 'vocational', 'technical_school']):
        if 'driving' not in cat and 'traffic' not in cat and 'bartending' not in cat:
            return 'Education'
    
    # Accommodation & Lodging
    if any(x in cat for x in ['hotel', 'motel', 'inn', 'resort', 'lodge', 'hostel', 'bed_and_breakfast',
                               'vacation_rental', 'cottage', 'cabin', 'apartment', 'condominium',
                               'housing', 'accommodation', 'campground', 'rv_park', 'guest_house',
                               'pension', 'houseboat']):
        return 'Accommodation & Lodging'
    
    # Professional Services
    if any(x in cat for x in ['lawyer', 'attorney', 'law', 'legal', 'accountant', 'bookkeeper', 'tax_service',
                               'financial', 'consultant', 'consulting', 'marketing', 'advertising',
                               'public_relations', 'design', 'architect', 'engineer',
                               'management', 'hr_', 'human_resource', 'employment', 'recruiting',
                               'temp_agency', 'notary', 'paralegal', 'mediator', 'appraisal',
                               'web_designer', 'graphic_designer', 'photographer', 'videographer',
                               'writer', 'editor', 'translation', 'interpreter', 'transcription']):
        if 'museum' not in cat and 'school' not in cat:
            return 'Professional Services'
    
    # Financial Services
    if any(x in cat for x in ['bank', 'credit_union', 'atm', 'insurance', 'loan', 'mortgage',
                               'investment', 'financial', 'broker', 'stock', 'currency_exchange',
                               'check_cashing', 'payday', 'bail_bonds', 'credit_counseling',
                               'debt_relief', 'accounting', 'tax_', 'bookkeeping']):
        if 'museum' not in cat:
            return 'Financial Services'
    
    # Real Estate
    if any(x in cat for x in ['real_estate', 'property_management', 'apartment_agent', 'housing',
                               'developer', 'home_staging', 'home_inspector']):
        return 'Real Estate'
    
    # Construction & Contractors
    if any(x in cat for x in ['contractor', 'construction', 'builder', 'plumbing', 'electrician',
                               'hvac', 'roofing', 'carpenter', 'mason', 'concrete', 'drywall',
                               'painting', 'remodeling', 'renovation', 'foundation', 'excavation',
                               'demolition', 'tiling', 'flooring', 'siding', 'insulation',
                               'waterproof', 'septic', 'well_drilling', 'paving']):
        if 'school' not in cat and 'supply' not in cat:
            return 'Construction & Contractors'
    
    # Home & Garden Services
    if any(x in cat for x in ['landscaping', 'lawn', 'gardener', 'tree_service', 'pest_control',
                               'cleaning', 'janitorial', 'maid', 'window_washing', 'carpet_cleaning',
                               'gutter', 'fence', 'deck', 'patio', 'pool_cleaning', 'handyman',
                               'locksmith', 'security_system', 'garage_door', 'door_service',
                               'appliance_repair', 'junk_removal', 'hauling', 'moving', 'movers',
                               'snow_removal', 'pressure_washing', 'chimney']):
        if 'store' not in cat and 'supply' not in cat:
            return 'Home & Garden Services'
    
    # Government & Public Services
    if any(x in cat for x in ['government', 'city_hall', 'town_hall', 'courthouse', 'dmv', 'motor_vehicle',
                               'post_office', 'police', 'fire_department', 'emergency_service',
                               'social_security', 'unemployment', 'welfare', 'public_health',
                               'department_of', 'office_of', 'bureau', 'agency', 'commission',
                               'federal', 'state', 'local', 'municipal', 'civic', 'embassy',
                               'military', 'army', 'navy', 'armed_forces', 'national_security',
                               'jail', 'prison', 'detention', 'passport', 'visa', 'customs']):
        if 'school' not in cat and 'museum' not in cat:
            return 'Government & Public Services'
    
    # Utilities & Infrastructure
    if any(x in cat for x in ['utility', 'electric', 'power_plant', 'energy', 'water_supplier',
                               'sewage', 'sanitation', 'waste', 'garbage', 'recycling',
                               'telecommunications', 'internet', 'cable', 'phone_service',
                               'pipeline', 'dam', 'bridge', 'tunnel', 'toll_station']):
        if 'repair' not in cat and 'installation' not in cat:
            return 'Utilities & Infrastructure'
    
    # Religious & Spiritual
    if any(x in cat for x in ['church', 'temple', 'mosque', 'synagogue', 'cathedral', 'chapel',
                               'religious', 'spiritual', 'monastery', 'convent', 'shrine',
                               'meditation', 'buddhist', 'hindu', 'christian', 'catholic', 'protestant',
                               'episcopal', 'baptist', 'pentecostal', 'evangelical', 'jehovah',
                               'sikh', 'mission', 'parish', 'astrologer', 'psychic', 'mystic']):
        return 'Religious & Spiritual'
    
    # Transportation
    if any(x in cat for x in ['airport', 'train_station', 'bus_station', 'metro', 'subway', 'transit',
                               'ferry', 'port', 'terminal', 'taxi', 'ride_sharing',
                               'limo', 'shuttle', 'transportation', 'parking',
                               'airline', 'railway', 'railroad', 'seaplane', 'heliport',
                               'cable_car', 'light_rail']):
        if 'museum' not in cat and 'repair' not in cat and 'dealer' not in cat:
            return 'Transportation'
    
    # Tourism & Attractions
    if any(x in cat for x in ['tourist', 'attraction', 'tours', 'sightseeing', 'visitor_center',
                               'lighthouse', 'monument', 'landmark', 'castle', 'palace', 'fort',
                               'historical', 'memorial', 'sculpture', 'statue', 'fountain',
                               'lookout', 'observation', 'scenic']):
        return 'Tourism & Attractions'
    
    # Parks & Natural Features
    if any(x in cat for x in ['park', 'playground', 'garden', 'nature_reserve', 'national_park',
                               'state_park', 'wildlife', 'sanctuary', 'preserve',
                               'mountain', 'hill', 'valley', 'canyon', 'cave', 'forest',
                               'desert', 'beach', 'coast', 'island', 'lake', 'river',
                               'waterfall', 'spring', 'dam', 'reservoir', 'marsh', 'wetland',
                               'dune', 'cliff', 'volcano', 'geyser', 'hot_springs']):
        if 'amusement' not in cat and 'theme' not in cat and 'water_park' not in cat:
            return 'Parks & Natural Features'
    
    # Agriculture & Farming
    if any(x in cat for x in ['farm', 'ranch', 'orchard', 'vineyard', 'agriculture', 'agricultural',
                               'livestock', 'cattle', 'dairy', 'poultry', 'pig_', 'fish_farm',
                               'crop', 'grain', 'produce', 'harvest', 'bee', 'honey', 'apiary',
                               'csa_farm', 'urban_farm', 'pumpkin_patch', 'pick_your_own']):
        if 'insurance' not in cat and 'equipment' not in cat and 'supply' not in cat:
            return 'Agriculture & Farming'
    
    # Manufacturing & Industrial
    if any(x in cat for x in ['manufacturing', 'manufacturer', 'factory', 'plant', 'mill', 'foundry',
                               'refinery', 'industrial', 'production', 'assembly', 'fabrication',
                               'processing', 'packaging', 'bottling', 'printing', 'publishing',
                               'textile', 'chemical', 'plastic', 'metal', 'steel', 'iron',
                               'lumber', 'paper', 'warehouse', 'distribution', 'mining',
                               'quarry', 'oil_and_gas', 'petroleum', 'coal']):
        if 'store' not in cat and 'repair' not in cat:
            return 'Manufacturing & Industrial'
    
    # Media & Communications
    if any(x in cat for x in ['media', 'newspaper', 'magazine', 'radio_station', 'tv_station',
                               'television_station', 'broadcasting', 'publisher', 'press',
                               'news', 'journalism', 'social_media']):
        return 'Media & Communications'
    
    # Technology & IT
    if any(x in cat for x in ['software', 'it_', 'computer_repair', 'tech_support', 'web_hosting',
                               'data_recovery', 'network', 'cybersecurity', 'biotechnology',
                               'scientific_laboratory', 'research_institute']):
        return 'Technology & IT'
    
    # Event Services
    if any(x in cat for x in ['event_planning', 'wedding_planning', 'party_', 'catering', 'venue',
                               'dj_', 'entertainment_service', 'rental_service', 'photo_booth',
                               'balloon_', 'florist', 'floral']):
        if 'supply' not in cat:
            return 'Event Services'
    
    # Pet Services
    if any(x in cat for x in ['pet_', 'dog_', 'animal_', 'veterinary', 'groomer', 'boarding',
                               'training', 'walker', 'sitter', 'adoption', 'shelter', 'rescue']):
        if 'store' not in cat and 'hospital' not in cat and 'supply' not in cat:
            return 'Pet Services'
    
    # Personal Services
    if any(x in cat for x in ['tailor', 'alterations', 'dry_cleaning', 'laundry', 'shoe_repair',
                               'watch_repair', 'jewelry_repair', 'engraving', 'framing',
                               'photo_', 'portrait', 'life_coach', 'personal_trainer',
                               'personal_chef', 'personal_assistant', 'concierge', 'valet',
                               'matchmaker', 'dating']):
        if 'supply' not in cat and 'equipment' not in cat:
            return 'Personal Services'
    
    # Community & Social Services
    if any(x in cat for x in ['community_center', 'social_service', 'charity', 'non_profit', 'nonprofit',
                               'volunteer', 'donation', 'shelter', 'homeless', 'food_bank',
                               'community_garden', 'youth', 'senior', 'elder', 'disability',
                               'counseling', 'crisis', 'suicide_prevention', 'abuse', 'addiction',
                               'rehabilitation', 'foster_care', 'adoption', 'veterans',
                               'refugee', 'fraternal', 'association', 'organization', 'union']):
        return 'Community & Social Services'
    
    # Business-to-Business
    if 'b2b' in cat or ('wholesaler' in cat and 'wholesale' not in cat) or 'distributor' in cat or 'supplier' in cat:
        return 'Business-to-Business'
    
    # Default category for uncategorized items
    return 'Other Services'


def main():
    """Main function to process the CSV file."""
    input_file = 'OM Catgories.csv'
    output_file = 'OM Catgories.csv'
    
    # Read the original CSV
    categories = []
    with open(input_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            categories.append(row['CATEGORY_LABEL'])
    
    # Create output with simplified taxonomy
    output_data = []
    for cat in categories:
        simplified = get_simplified_category(cat)
        output_data.append({
            'CATEGORY_LABEL': cat,
            'SIMPLIFIED_CATEGORY': simplified
        })
    
    # Write to CSV
    with open(output_file, 'w', newline='') as f:
        fieldnames = ['CATEGORY_LABEL', 'SIMPLIFIED_CATEGORY']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(output_data)
    
    # Print summary statistics
    print(f"Successfully processed {len(categories)} categories")
    print(f"\nOutput written to: {output_file}")
    print("\nSimplified taxonomy summary:")
    
    category_counts = {}
    for row in output_data:
        cat = row['SIMPLIFIED_CATEGORY']
        category_counts[cat] = category_counts.get(cat, 0) + 1
    
    for cat in sorted(category_counts.keys()):
        print(f"  {cat}: {category_counts[cat]} categories")
    
    print(f"\nTotal simplified categories: {len(category_counts)}")


if __name__ == '__main__':
    main()
