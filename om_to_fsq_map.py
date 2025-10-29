#!/usr/bin/env python3
import argparse
import csv
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from typing import List, Dict, Tuple, Optional

try:
    from rapidfuzz import process, fuzz
except Exception as e:
    raise SystemExit("Missing dependency rapidfuzz. Please run: pip install rapidfuzz")


@dataclass
class FSQCategory:
    category_id: str
    category_label: str
    category_primary: str
    category_secondary: str
    leaf_label: str


def normalize_text(value: str) -> str:
    if value is None:
        return ""
    text = str(value).strip().lower()
    # Strip accents (e.g., café -> cafe)
    text = unicodedata.normalize('NFKD', text)
    text = text.encode('ascii', 'ignore').decode('ascii')
    # Replace common separators
    text = text.replace("&", " and ")
    text = text.replace("/", " ")
    text = text.replace("_", " ")
    text = text.replace("-", " ")
    # Canonicalize British vs American spellings and common variants
    replacements = {
        "centre": "center",
        "theatre": "theater",
        "tyre": "tire",
        "tyres": "tires",
        "jewellery": "jewelry",
        "behaviour": "behavior",
        "barbeque": "barbecue",
        "boulangerie": "bakery",
        "shoppe": "shop",
    }
    for src, dst in replacements.items():
        text = re.sub(rf"\b{re.escape(src)}\b", dst, text)
    # Normalize multi-spaces and trim punctuation
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_leaf_label(category_label: str) -> str:
    if not category_label:
        return ""
    # FSQ labels use ` > ` as a hierarchy separator
    parts = [p.strip() for p in category_label.split('>')]
    return parts[-1] if parts else category_label


def load_fsq_categories(path: str) -> Tuple[List[FSQCategory], List[str], List[int]]:
    fsq_rows: List[FSQCategory] = []
    candidate_texts: List[str] = []
    candidate_to_index: List[int] = []  # maps candidate_text index to fsq_rows index

    with open(path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        # Expected headers: Category ID, Category Label, Category_Primary, Category_Secondary
        for row in reader:
            cat_id = row.get('Category ID', '')
            label = row.get('Category Label', '')
            primary = row.get('Category_Primary', '')
            secondary = row.get('Category_Secondary', '')
            leaf = extract_leaf_label(label)
            fsq = FSQCategory(
                category_id=cat_id,
                category_label=label,
                category_primary=primary,
                category_secondary=secondary,
                leaf_label=leaf,
            )
            idx = len(fsq_rows)
            fsq_rows.append(fsq)

            # Candidates: full label and leaf label
            full_norm = normalize_text(label)
            leaf_norm = normalize_text(leaf)

            # Avoid empty candidates
            if full_norm:
                candidate_texts.append(full_norm)
                candidate_to_index.append(idx)
            if leaf_norm and leaf_norm != full_norm:
                candidate_texts.append(leaf_norm)
                candidate_to_index.append(idx)

    return fsq_rows, candidate_texts, candidate_to_index


def choose_best_matches(
    query: str,
    candidate_texts: List[str],
    candidate_to_index: List[int],
    limit: int = 8,
    allowed_fsq_indices: Optional[set] = None,
) -> List[Tuple[int, int, str]]:
    """
    Returns top matches grouped by FSQ row idx.
    Each tuple: (fsq_idx, score, matched_text)
    """
    # Use WRatio for robust token/partial matching
    # Optionally filter the candidate space to approved FSQ indices
    if allowed_fsq_indices is not None:
        filtered_texts = []
        filtered_map = []
        for text, idx in zip(candidate_texts, candidate_to_index):
            if idx in allowed_fsq_indices:
                filtered_texts.append(text)
                filtered_map.append(idx)
        search_texts = filtered_texts if filtered_texts else candidate_texts
        search_map = filtered_map if filtered_texts else candidate_to_index
    else:
        search_texts = candidate_texts
        search_map = candidate_to_index

    results = process.extract(
        query,
        search_texts,
        scorer=fuzz.WRatio,
        limit=limit * 3,  # grab extra before grouping
    )
    grouped: Dict[int, Tuple[int, str]] = {}
    for cand_text, score, cand_idx in results:
        fsq_idx = search_map[cand_idx]
        prev = grouped.get(fsq_idx)
        if prev is None or score > prev[0]:
            grouped[fsq_idx] = (score, cand_text)
    # Sort and keep top N by score
    top = sorted(((fsq_idx, sc, mt) for fsq_idx, (sc, mt) in grouped.items()), key=lambda x: x[1], reverse=True)
    return top[:limit]


def map_om_to_fsq(
    om_path: str,
    fsq_path: str,
    output_path: str,
    ambiguous_path: Optional[str] = None,
    threshold: int = 86,
) -> None:
    fsq_rows, candidate_texts, candidate_to_index = load_fsq_categories(fsq_path)

    # Build a quick index of FSQ primary/secondary labels (normalized) to row indices
    fsq_primary_to_indices: Dict[str, List[int]] = defaultdict(list)
    fsq_secondary_to_indices: Dict[Tuple[str, str], List[int]] = defaultdict(list)
    for idx, fsq in enumerate(fsq_rows):
        primary_norm = normalize_text(fsq.category_primary)
        secondary_norm = normalize_text(fsq.category_secondary)
        fsq_primary_to_indices[primary_norm].append(idx)
        fsq_secondary_to_indices[(primary_norm, secondary_norm)].append(idx)

    # Map OM simplified categories to allowed FSQ primary categories
    om_to_fsq_primary = {
        'accommodation and lodging': {'travel and transportation', 'community and government', 'landmarks and outdoors'},
        'food and dining': {'dining and drinking'},
        'retail and shopping': {'retail'},
        'healthcare and medical': {'health and medicine'},
        'beauty and personal care': {'business and professional services', 'health and medicine'},
        'entertainment and recreation': {'arts and entertainment', 'sports and recreation'},
        'government and public services': {'community and government'},
        'transportation': {'travel and transportation'},
        'home and garden': {'business and professional services', 'retail'},
        'professional services': {'business and professional services'},
        'industrial and manufacturing': {'business and professional services'},
        'community and social services': {'community and government'},
        'religious and spiritual': {'community and government'},
        'education and learning': {'community and government'},
        'natural features and outdoor': {'landmarks and outdoors'},
        'automotive': {'business and professional services', 'retail', 'travel and transportation'},
        'other': set(),
    }

    def allowed_indices_for_om(om_simplified: str, om_updated: str, om_label: str) -> Optional[set]:
        simp = normalize_text(om_simplified)
        updated = normalize_text(om_updated)
        allowed_primaries = set(om_to_fsq_primary.get(simp, set()))
        # Business-to-Business often maps to Business and Professional Services
        if 'business to business' in updated or updated == 'b2b':
            allowed_primaries.add('business and professional services')
        if not allowed_primaries:
            return None
        indices: set = set()
        for primary in allowed_primaries:
            indices.update(fsq_primary_to_indices.get(primary, []))

        # Narrow further for lodging-related categories to avoid unrelated matches
        if simp == 'accommodation and lodging':
            narrowed: set = set()
            # Keep travel and transportation lodging/rv park
            for sec in ('lodging', 'rv park'):
                narrowed.update(fsq_secondary_to_indices.get(('travel and transportation', sec), []))
            # Also keep community/government housing-related
            for sec in (
                'housing authority', 'residential building', 'housing development', 'organization',
            ):
                narrowed.update(fsq_secondary_to_indices.get(('community and government', sec), []))
            # Include campground under landmarks/outdoors as accommodation-adjacent
            for sec in ('campground',):
                narrowed.update(fsq_secondary_to_indices.get(('landmarks and outdoors', sec), []))
            if narrowed:
                # Intersect with initially allowed
                indices = indices.intersection(narrowed)
        return indices or None

    with open(om_path, newline='', encoding='utf-8') as f_in, \
         open(output_path, 'w', newline='', encoding='utf-8') as f_out, \
         open(ambiguous_path, 'w', newline='', encoding='utf-8') if ambiguous_path else open('/dev/null', 'w') as f_amb:
        reader = csv.DictReader(f_in)
        fieldnames = [
            'OM_CATEGORY_LABEL', 'OM_SIMPLIFIED_CATEGORY', 'OM_UPDATED_CATEGORY',
            'FSQ_CATEGORY_ID', 'FSQ_CATEGORY_LABEL', 'FSQ_CATEGORY_PRIMARY', 'FSQ_CATEGORY_SECONDARY',
            'MATCH_SCORE', 'MATCHED_TEXT', 'ALTERNATES'
        ]
        writer = csv.DictWriter(f_out, fieldnames=fieldnames)
        writer.writeheader()

        amb_writer = None
        if ambiguous_path:
            amb_writer = csv.DictWriter(f_amb, fieldnames=fieldnames)
            amb_writer.writeheader()

        for row in reader:
            om_label = row.get('CATEGORY_LABEL') or row.get('Category Label') or ''
            om_simplified = row.get('SIMPLIFIED_CATEGORY', '')
            om_updated = row.get('UPDATED_CATEGORY', '')

            q = normalize_text(om_label)
            if not q:
                continue

            allowed = allowed_indices_for_om(om_simplified, om_updated, om_label)
            top = choose_best_matches(q, candidate_texts, candidate_to_index, limit=5, allowed_fsq_indices=allowed)
            # Build alternates list string for context
            alternates: List[str] = []

            best_fsq_idx = None
            best_score = -1
            best_matched_text = ''

            for fsq_idx, score, matched_text in top:
                fsq = fsq_rows[fsq_idx]
                label_for_alt = f"{fsq.category_label} (ID {fsq.category_id})"
                alternates.append(f"{label_for_alt} [{score}]")
                if score > best_score:
                    best_score = score
                    best_fsq_idx = fsq_idx
                    best_matched_text = matched_text

            if best_fsq_idx is None:
                continue

            fsq = fsq_rows[best_fsq_idx]
            out_row = {
                'OM_CATEGORY_LABEL': om_label,
                'OM_SIMPLIFIED_CATEGORY': om_simplified,
                'OM_UPDATED_CATEGORY': om_updated,
                'FSQ_CATEGORY_ID': fsq.category_id,
                'FSQ_CATEGORY_LABEL': fsq.category_label,
                'FSQ_CATEGORY_PRIMARY': fsq.category_primary,
                'FSQ_CATEGORY_SECONDARY': fsq.category_secondary,
                'MATCH_SCORE': best_score,
                'MATCHED_TEXT': best_matched_text,
                'ALTERNATES': '; '.join(alternates),
            }

            writer.writerow(out_row)
            if amb_writer and best_score < threshold:
                amb_writer.writerow(out_row)


def main():
    parser = argparse.ArgumentParser(description='Map OM categories to closest FSQ categories using fuzzy matching.')
    parser.add_argument('--om', default='OM Category Updated 20251028.csv', help='Path to OM categories CSV')
    parser.add_argument('--fsq', default='FSQ Categories.csv', help='Path to FSQ categories CSV')
    parser.add_argument('--out', default='OM_to_FSQ_Mapping.csv', help='Output CSV path for mapping')
    parser.add_argument('--ambiguous_out', default='OM_to_FSQ_Mapping_Ambiguous.csv', help='Output CSV for low-confidence matches')
    parser.add_argument('--threshold', type=int, default=86, help='Score threshold for marking a match as ambiguous')
    args = parser.parse_args()

    map_om_to_fsq(args.om, args.fsq, args.out, args.ambiguous_out, args.threshold)


if __name__ == '__main__':
    main()
