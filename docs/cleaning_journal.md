## Step 0: CSV to TSV conversion
- Problem: Some fields contain commas inside quotes (e.g. agency names, Organization Type), so splitting on commas breaks columns.
- Command:
  awk -F'"' -v OFS='' '{ for (i = 1; i <= NF; i += 2) gsub(/,/, "\t", $i); print }' data/raw/Operating_Expenses_by_Type_2020.csv > data/clean/step0.tsv
- Checks: file contains no escaped quotes ("") and no tab characters, so conversion is safe.
- Result: all 4,370 lines (header + 4,369 rows) have 49 fields; no malformed rows.
- Raw file unchanged; output in data/clean/step0.tsv.