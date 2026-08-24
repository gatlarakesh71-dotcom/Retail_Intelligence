import csv
import os

folder = r"e:\B. Data Analyst\2. Bootcamp\Project-1( Retail Intelligence )\2. Clean Data\Project 1"

for file in sorted(os.listdir(folder)):
    if not file.endswith('.csv'):
        continue
    path = os.path.join(folder, file)
    with open(path, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames or []

    row_count = len(rows)
    missing_counts = []
    for field in fieldnames:
        count = 0
        for row in rows:
            value = row.get(field)
            if value is None or value.strip() == '':
                count += 1
        if count > 0:
            missing_counts.append((field, count))

    print(f'FILE: {file}')
    print(f'ROWS: {row_count}')
    if not missing_counts:
        print('MISSING_VALUES: none')
    else:
        print('MISSING_VALUES:')
        for field, count in missing_counts:
            print(f'  {field}: {count}')
        print(f'TOTAL_MISSING: {sum(count for _, count in missing_counts)}')
    print('-' * 60)
