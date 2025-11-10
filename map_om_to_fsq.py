#!/usr/bin/env python3
import csv
import re
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Dict, List, Tuple

try:
    from rapidfuzz import process, fuzz
except Exception as e:
    print("RapidFuzz not installed. Please install with: pip install rapidfuzz", file=sys.stderr)
    raise

WORKSPACE = Path(__file__).resolve().parent
FSQ_PATH = WORKSPACE / "FSQ Categories.csv"
OM_PATH = WORKSPACE / "OM Category Updated 20251028.csv"
OUT_PATH = WORKSPACE / "OM_to_FSQ_Category_Mapping.csv"

NON_ALNUM = re.compile(r"[^a-z0-9 &]")
AMPERSAND = re.compile(r"\b(and|\&)\b")
MULTISPACE = re.compile(r"\s+")
UNDERSCORES = re.compile(r"_+")


def normalize(text: str) -> str:
    if text is None:
        return ""
    t = text.strip().lower()
    t = UNDERSCORES.sub(" ", t)
    t = AMPERSAND.sub(" and ", t)
    t = NON_ALNUM.sub(" ", t)
    t = MULTISPACE.sub(" ", t)
    return t.strip()


def load_fsq_categories() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    with FSQ_PATH.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = row.get("Category Label") or row.get("Category_Label") or row.get("CATEGORY_LABEL")
            if not label:
                # Skip malformed rows
                continue
            norm = normalize(label)
            # Prefer leaf-most token for additional matching strength
            leaf = label.split(" > ")[-1].strip()
            norm_leaf = normalize(leaf)
            rows.append({
                "Category ID": row.get("Category ID") or row.get("Category_ID") or row.get("CATEGORY_ID"),
                "Category Label": label,
                "Category_Primary": row.get("Category_Primary", ""),
                "Category_Secondary": row.get("Category_Secondary", ""),
                "_norm": norm,
                "_norm_leaf": norm_leaf,
            })
    return rows


def load_unique_om_labels() -> List[str]:
    uniq = OrderedDict()
    with OM_PATH.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        # The column appears to be CATEGORY_LABEL
        for row in reader:
            label = row.get("Category Label") or row.get("CATEGORY_LABEL") or row.get("category_label")
            if not label:
                continue
            uniq[label] = None
    return list(uniq.keys())


def combined_score(query: str, candidate: str, candidate_leaf: str) -> float:
    # Blend token_set_ratio and partial_ratio across full label and leaf label
    s1 = fuzz.token_set_ratio(query, candidate)
    s2 = fuzz.partial_ratio(query, candidate)
    s3 = fuzz.token_set_ratio(query, candidate_leaf)
    s4 = fuzz.partial_ratio(query, candidate_leaf)
    # Weighted average emphasizes token_set and leaf
    return 0.35 * s1 + 0.25 * s2 + 0.25 * s3 + 0.15 * s4


def build_fsq_corpus(fsq_rows: List[Dict[str, str]]):
    # Return structures for fast matching
    labels = [r["Category Label"] for r in fsq_rows]
    norm_full = [r["_norm"] for r in fsq_rows]
    norm_leaf = [r["_norm_leaf"] for r in fsq_rows]
    return labels, norm_full, norm_leaf


def match_one(query_label: str, fsq_rows: List[Dict[str, str]], labels: List[str], norm_full: List[str], norm_leaf: List[str], topn: int = 3) -> List[Tuple[int, float]]:
    q = normalize(query_label)
    # Use RapidFuzz to get a shortlist using token_set_ratio on leaf and full text, then re-rank via combined_score
    # First pass on full norms
    shortlist_full = process.extract(q, norm_full, scorer=fuzz.token_set_ratio, limit=max(50, topn * 10))
    # Also shortlist on leaf norms
    shortlist_leaf = process.extract(q, norm_leaf, scorer=fuzz.token_set_ratio, limit=max(50, topn * 10))

    indices = set()
    for cand, score, idx in shortlist_full:
        indices.add(idx)
    for cand, score, idx in shortlist_leaf:
        indices.add(idx)

    rescored: List[Tuple[int, float]] = []
    for idx in indices:
        score = combined_score(q, norm_full[idx], norm_leaf[idx])
        rescored.append((idx, score))

    rescored.sort(key=lambda x: x[1], reverse=True)
    return rescored[:topn]


def main():
    if not FSQ_PATH.exists() or not OM_PATH.exists():
        print(f"Input files not found. Expected: {FSQ_PATH} and {OM_PATH}", file=sys.stderr)
        sys.exit(1)

    fsq_rows = load_fsq_categories()
    om_labels = load_unique_om_labels()

    labels, norm_full, norm_leaf = build_fsq_corpus(fsq_rows)

    # Prepare output
    with OUT_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "OM_CATEGORY_LABEL",
            "FSQ_BEST_LABEL",
            "FSQ_BEST_ID",
            "FSQ_BEST_PRIMARY",
            "FSQ_BEST_SECONDARY",
            "BEST_SCORE",
            "FSQ_ALT1_LABEL",
            "ALT1_ID",
            "ALT1_SCORE",
            "FSQ_ALT2_LABEL",
            "ALT2_ID",
            "ALT2_SCORE",
            "NEEDS_REVIEW"
        ])

        for om_label in om_labels:
            matches = match_one(om_label, fsq_rows, labels, norm_full, norm_leaf, topn=3)
            # Ensure we have three entries
            while len(matches) < 3:
                matches.append((0, 0.0))

            (i0, s0), (i1, s1), (i2, s2) = matches

            def row_at(i: int):
                if i < 0 or i >= len(fsq_rows):
                    return {
                        "Category Label": "",
                        "Category ID": "",
                        "Category_Primary": "",
                        "Category_Secondary": "",
                    }
                return fsq_rows[i]

            r0 = row_at(i0)
            r1 = row_at(i1)
            r2 = row_at(i2)

            needs_review = "TRUE" if s0 < 80 else "FALSE"

            writer.writerow([
                om_label,
                r0.get("Category Label", ""),
                r0.get("Category ID", ""),
                r0.get("Category_Primary", ""),
                r0.get("Category_Secondary", ""),
                f"{s0:.1f}",
                r1.get("Category Label", ""),
                r1.get("Category ID", ""),
                f"{s1:.1f}",
                r2.get("Category Label", ""),
                r2.get("Category ID", ""),
                f"{s2:.1f}",
                needs_review,
            ])

    print(f"Wrote mapping: {OUT_PATH}")


if __name__ == "__main__":
    main()
