-- ================================================================
-- Overture Maps Category Simplification SQL Script for Snowflake
-- ================================================================
-- This script creates a UDF (User-Defined Function) to map granular 
-- Overture Maps categories to a simplified 30-category taxonomy
--
-- Author: AI Assistant
-- Date: 2025-10-22
-- ================================================================

-- CREATE FUNCTION: SIMPLIFY_CATEGORY
-- Maps a category label to its simplified taxonomy category
CREATE OR REPLACE FUNCTION SIMPLIFY_CATEGORY(category_input VARCHAR)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS
$$
  if (!category_input) return 'Other Services';
  
  var cat = category_input.toLowerCase();
  
  // Food & Dining
  var foodKeywords = ['restaurant', 'cafe', 'coffee', 'food', 'dining', '_bar', 'pub', 'brewery', 'winery', 
                      'bakery', 'pizza', 'burger', 'sandwich', 'diner', 'bistro', 'eatery', 'caterer',
                      'donuts', 'ice_cream', 'dessert', 'candy', 'chocolate', 'patisserie', 'bagel',
                      'taco', 'barbecue', 'steakhouse', 'gastropub', 'brasserie', 'lounge',
                      'cocktail', 'wine_bar', 'beer_bar', 'speakeasy', 'champagne_bar', 'sake_bar',
                      'hookah', 'cigar_bar', 'tea_room', 'juice_bar', 'smoothie', 'meat_shop', 'butcher',
                      'seafood', 'delicatessen', 'cheese_shop', 'pasta_shop', 'pie_shop', 'cupcake',
                      'empanadas', 'pretzel', 'popcorn', 'hot_dog', 'chicken_wings', 'poke', 'doner',
                      'falafel', 'dumpling', 'noodles', 'sushi', 'dim_sum', 'waffle', 'pancake',
                      'gelato', 'frozen_yoghurt', 'shaved_ice', 'acai', 'kombucha', 'bubble_tea',
                      'cidery', 'distillery', 'eat_and_drink', 'tapas'];
  for (var i = 0; i < foodKeywords.length; i++) {
    if (cat.includes(foodKeywords[i])) return 'Food & Dining';
  }
  
  // Healthcare & Medical
  var healthKeywords = ['doctor', 'physician', 'medical', 'health', 'clinic', 'hospital', 'dentist', 'dental',
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
                        'doula', 'maternity', 'prenatal', 'lactation', 'abortion', 'mohel'];
  for (var i = 0; i < healthKeywords.length; i++) {
    if (cat.includes(healthKeywords[i])) return 'Healthcare & Medical';
  }
  
  // Retail & Shopping
  var retailKeywords = ['store', 'shop', 'retail', 'boutique', 'market', 'supermarket', 'grocery',
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
                        'tobacco_shop', 'vape', 'e_cigarette'];
  for (var i = 0; i < retailKeywords.length; i++) {
    if (cat.includes(retailKeywords[i])) return 'Retail & Shopping';
  }
  
  // Automotive (excluding museums)
  var autoKeywords = ['auto', 'automotive', 'car_', 'vehicle', 'truck_', 'motorcycle', 'scooter_dealer',
                      'mechanic', 'tire', 'brake', 'transmission', 'muffler', 'body_shop',
                      'detailing', 'car_wash', 'towing', 'gas_station', 'fuel_', 'oil_change',
                      'emissions', 'windshield', 'window_tint', 'customization'];
  for (var i = 0; i < autoKeywords.length; i++) {
    if (cat.includes(autoKeywords[i]) && !cat.includes('museum')) return 'Automotive';
  }
  
  // Beauty & Wellness
  var beautyKeywords = ['salon', 'barber', 'hair_', 'nail_', 'spa', 'beauty', 'esthetician',
                        'massage', 'wax', 'laser_hair', 'eyelash', 'eyebrow', 'tanning',
                        'tattoo', 'piercing', 'makeup', 'skin_care', 'aromatherapy',
                        'fitness', 'gym', 'yoga', 'pilates', 'trainer', 'weight_loss'];
  for (var i = 0; i < beautyKeywords.length; i++) {
    if (cat.includes(beautyKeywords[i]) && !cat.includes('supply') && !cat.includes('school')) {
      return 'Beauty & Wellness';
    }
  }
  
  // Sports & Recreation
  var sportsKeywords = ['sports', 'stadium', 'arena', 'field', 'court', 'track', 'pitch',
                        'golf', 'bowling', 'skating', 'ski_', 'tennis', 'basketball',
                        'football', 'soccer', 'baseball', 'hockey', 'volleyball', 'rugby',
                        'swimming_pool', 'climbing', 'trail', 'hiking'];
  for (var i = 0; i < sportsKeywords.length; i++) {
    if (cat.includes(sportsKeywords[i]) && !cat.includes('museum') && !cat.includes('store')) {
      return 'Sports & Recreation';
    }
  }
  
  // Arts & Entertainment
  var artsKeywords = ['museum', 'gallery', 'theater', 'theatre', 'cinema', 'movie',
                      'concert', 'music_venue', 'comedy', 'nightclub', 'amusement',
                      'theme_park', 'water_park', 'zoo', 'aquarium', 'casino',
                      'arcade', 'festival', 'carnival', 'circus', 'planetarium'];
  for (var i = 0; i < artsKeywords.length; i++) {
    if (cat.includes(artsKeywords[i])) return 'Arts & Entertainment';
  }
  
  // Education
  var eduKeywords = ['school', 'university', 'college', 'education', 'preschool',
                     'kindergarten', 'elementary', 'high_school', 'tutoring', 'library'];
  for (var i = 0; i < eduKeywords.length; i++) {
    if (cat.includes(eduKeywords[i]) && !cat.includes('driving')) {
      return 'Education';
    }
  }
  
  // Accommodation & Lodging
  var accomKeywords = ['hotel', 'motel', 'inn', 'resort', 'lodge', 'hostel',
                       'bed_and_breakfast', 'vacation_rental', 'cottage', 'cabin',
                       'campground', 'rv_park'];
  for (var i = 0; i < accomKeywords.length; i++) {
    if (cat.includes(accomKeywords[i])) return 'Accommodation & Lodging';
  }
  
  // Professional Services
  var profKeywords = ['lawyer', 'attorney', 'accountant', 'consultant', 'marketing',
                      'advertising', 'architect', 'engineer', 'photographer',
                      'videographer', 'designer'];
  for (var i = 0; i < profKeywords.length; i++) {
    if (cat.includes(profKeywords[i]) && !cat.includes('museum')) {
      return 'Professional Services';
    }
  }
  
  // Financial Services
  var finKeywords = ['bank', 'credit_union', 'atm', 'insurance', 'loan', 'mortgage',
                     'investment', 'broker'];
  for (var i = 0; i < finKeywords.length; i++) {
    if (cat.includes(finKeywords[i])) return 'Financial Services';
  }
  
  // Real Estate
  if (cat.includes('real_estate') || cat.includes('property_management')) {
    return 'Real Estate';
  }
  
  // Construction & Contractors
  var constructionKeywords = ['contractor', 'construction', 'plumbing', 'electrician',
                              'hvac', 'roofing', 'carpenter', 'remodeling', 'renovation'];
  for (var i = 0; i < constructionKeywords.length; i++) {
    if (cat.includes(constructionKeywords[i]) && !cat.includes('supply')) {
      return 'Construction & Contractors';
    }
  }
  
  // Home & Garden Services
  var homeKeywords = ['landscaping', 'lawn', 'gardener', 'pest_control', 'cleaning',
                      'window_washing', 'handyman', 'locksmith', 'movers'];
  for (var i = 0; i < homeKeywords.length; i++) {
    if (cat.includes(homeKeywords[i]) && !cat.includes('store')) {
      return 'Home & Garden Services';
    }
  }
  
  // Government & Public Services
  var govKeywords = ['government', 'city_hall', 'town_hall', 'courthouse', 'dmv',
                     'post_office', 'police', 'fire_department', 'embassy', 'military'];
  for (var i = 0; i < govKeywords.length; i++) {
    if (cat.includes(govKeywords[i])) return 'Government & Public Services';
  }
  
  // Utilities & Infrastructure
  var utilityKeywords = ['utility', 'power_plant', 'water_supplier', 'waste', 'garbage',
                         'recycling', 'telecommunications', 'pipeline', 'dam', 'bridge'];
  for (var i = 0; i < utilityKeywords.length; i++) {
    if (cat.includes(utilityKeywords[i]) && !cat.includes('repair')) {
      return 'Utilities & Infrastructure';
    }
  }
  
  // Religious & Spiritual
  var religKeywords = ['church', 'temple', 'mosque', 'synagogue', 'cathedral', 'chapel',
                       'religious', 'monastery', 'meditation', 'spiritual'];
  for (var i = 0; i < religKeywords.length; i++) {
    if (cat.includes(religKeywords[i])) return 'Religious & Spiritual';
  }
  
  // Transportation
  var transKeywords = ['airport', 'train_station', 'bus_station', 'metro', 'subway',
                       'ferry', 'terminal', 'taxi', 'parking', 'airline', 'railway'];
  for (var i = 0; i < transKeywords.length; i++) {
    if (cat.includes(transKeywords[i]) && !cat.includes('museum')) {
      return 'Transportation';
    }
  }
  
  // Tourism & Attractions
  var tourKeywords = ['tourist', 'attraction', 'tours', 'sightseeing', 'lighthouse',
                      'monument', 'landmark', 'castle', 'palace', 'fort'];
  for (var i = 0; i < tourKeywords.length; i++) {
    if (cat.includes(tourKeywords[i])) return 'Tourism & Attractions';
  }
  
  // Parks & Natural Features
  var parkKeywords = ['park', 'garden', 'national_park', 'state_park', 'nature_reserve',
                      'mountain', 'beach', 'lake', 'river', 'waterfall', 'forest'];
  for (var i = 0; i < parkKeywords.length; i++) {
    if (cat.includes(parkKeywords[i]) && !cat.includes('amusement') && !cat.includes('theme')) {
      return 'Parks & Natural Features';
    }
  }
  
  // Agriculture & Farming
  var farmKeywords = ['farm', 'ranch', 'orchard', 'agriculture', 'livestock', 'dairy',
                      'poultry', 'crop', 'grain'];
  for (var i = 0; i < farmKeywords.length; i++) {
    if (cat.includes(farmKeywords[i]) && !cat.includes('equipment')) {
      return 'Agriculture & Farming';
    }
  }
  
  // Manufacturing & Industrial
  var mfgKeywords = ['manufacturing', 'manufacturer', 'factory', 'plant', 'mill',
                     'industrial', 'warehouse', 'mining', 'refinery'];
  for (var i = 0; i < mfgKeywords.length; i++) {
    if (cat.includes(mfgKeywords[i]) && !cat.includes('store')) {
      return 'Manufacturing & Industrial';
    }
  }
  
  // Media & Communications
  var mediaKeywords = ['media', 'newspaper', 'magazine', 'radio_station', 'tv_station',
                       'broadcasting', 'publisher'];
  for (var i = 0; i < mediaKeywords.length; i++) {
    if (cat.includes(mediaKeywords[i])) return 'Media & Communications';
  }
  
  // Technology & IT
  var techKeywords = ['software', 'it_', 'web_hosting', 'data_recovery', 'biotechnology'];
  for (var i = 0; i < techKeywords.length; i++) {
    if (cat.includes(techKeywords[i])) return 'Technology & IT';
  }
  
  // Event Services
  var eventKeywords = ['event_planning', 'wedding_planning', 'catering', 'dj_', 'florist'];
  for (var i = 0; i < eventKeywords.length; i++) {
    if (cat.includes(eventKeywords[i]) && !cat.includes('supply')) {
      return 'Event Services';
    }
  }
  
  // Pet Services
  var petKeywords = ['pet_', 'dog_', 'groomer', 'boarding', 'walker', 'sitter'];
  for (var i = 0; i < petKeywords.length; i++) {
    if (cat.includes(petKeywords[i]) && !cat.includes('store') && !cat.includes('supply')) {
      return 'Pet Services';
    }
  }
  
  // Personal Services
  var personalKeywords = ['tailor', 'dry_cleaning', 'laundry', 'life_coach'];
  for (var i = 0; i < personalKeywords.length; i++) {
    if (cat.includes(personalKeywords[i])) return 'Personal Services';
  }
  
  // Community & Social Services
  var communityKeywords = ['community_center', 'social_service', 'charity', 'non_profit',
                           'shelter', 'food_bank', 'counseling'];
  for (var i = 0; i < communityKeywords.length; i++) {
    if (cat.includes(communityKeywords[i])) return 'Community & Social Services';
  }
  
  // Business-to-Business
  if (cat.includes('b2b') || cat.includes('wholesaler') || cat.includes('distributor') || cat.includes('supplier')) {
    return 'Business-to-Business';
  }
  
  // Default
  return 'Other Services';
$$;

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Example 1: Query with simplified categories
/*
SELECT 
  CATEGORY_LABEL,
  SIMPLIFY_CATEGORY(CATEGORY_LABEL) AS SIMPLIFIED_CATEGORY
FROM your_table_name
LIMIT 100;
*/

-- Example 2: Create a view with simplified categories
/*
CREATE OR REPLACE VIEW vw_overture_categories_simplified AS
SELECT 
  *,
  SIMPLIFY_CATEGORY(CATEGORY_LABEL) AS SIMPLIFIED_CATEGORY
FROM your_table_name;
*/

-- Example 3: Add column to existing table and update
/*
ALTER TABLE your_table_name ADD COLUMN SIMPLIFIED_CATEGORY VARCHAR;
UPDATE your_table_name 
SET SIMPLIFIED_CATEGORY = SIMPLIFY_CATEGORY(CATEGORY_LABEL);
*/

-- Example 4: Get category distribution
/*
SELECT 
  SIMPLIFY_CATEGORY(CATEGORY_LABEL) AS SIMPLIFIED_CATEGORY,
  COUNT(*) AS CATEGORY_COUNT,
  COUNT(DISTINCT CATEGORY_LABEL) AS UNIQUE_CATEGORIES
FROM your_table_name
GROUP BY SIMPLIFY_CATEGORY(CATEGORY_LABEL)
ORDER BY CATEGORY_COUNT DESC;
*/

-- Example 5: Create new table with simplified taxonomy
/*
CREATE TABLE tbl_overture_categories_with_taxonomy AS
SELECT 
  CATEGORY_LABEL,
  SIMPLIFY_CATEGORY(CATEGORY_LABEL) AS SIMPLIFIED_CATEGORY,
  COUNT(*) AS LOCATION_COUNT
FROM your_places_table
GROUP BY CATEGORY_LABEL, SIMPLIFY_CATEGORY(CATEGORY_LABEL);
*/

-- ================================================================
-- END OF SCRIPT
-- ================================================================
