#!/usr/bin/env python3
import csv
from pathlib import Path

in_path = Path('/workspace/OM_to_FSQ_Category_Mapping.csv')
out_path = Path('/workspace/OM_to_FSQ_Needs_Review.csv')

with in_path.open(newline='', encoding='utf-8') as f_in, out_path.open('w', newline='', encoding='utf-8') as f_out:
    reader = csv.DictReader(f_in)
    writer = csv.DictWriter(f_out, fieldnames=reader.fieldnames)
    writer.writeheader()
    for row in reader:
        if (row.get('NEEDS_REVIEW') or '').upper() == 'TRUE':
            writer.writerow(row)

print(f"Wrote: {out_path}")
