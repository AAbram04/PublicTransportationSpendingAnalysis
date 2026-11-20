# Cleaning Journal

## Step 0: CSV to TSV conversion
- Observation: Some fields (Agency, Organization Type) contain commas inside quotes,
  e.g. "Subsidiary Unit of a Transit Agency, Reporting Separately". Splitting on
  commas would shift columns.
- Decision: Convert to tab-separated. awk splits each line on quote marks; commas
  outside quotes become tabs, commas inside quotes are kept, quote marks are removed.
- Justification: Every later step can use awk -F'\t' safely. Uses plain awk (no gawk).
- Safety checks (script stops if either fails): file has no escaped quotes ("") and no
  existing tab characters.
- Verification: all 4,370 lines (header + 4,369 rows) have exactly 49 fields;
  0 malformed rows.

## Step 1: NTD ID / Legacy NTD ID standardization
- Observation: 130 Legacy IDs and 178 NTD IDs had only 1–4 digits because leading zeros
  were lost (e.g. King County "1" should be 0001 / 00001). 907 Legacy IDs are blank
  (569 of them are Reduced Asset Reporters). NTD ID is never blank, and each NTD ID
  has exactly one Legacy ID value.
- Decision:
  - Zero-pad numeric IDs: Legacy → 4 digits, NTD → 5 digits.
  - Keep rural (e.g. 7R03-017) and tribal (e.g. 6T02) formats unchanged.
  - Leave blank Legacy IDs blank; add a "Legacy ID Missing" (Yes/No) column.
  - Any ID not matching a valid format is sent to rejected.tsv with the reason.
  - Columns are located by header name, not position.
- Justification: NTD ID is complete and unique per agency, so it is used as the agency
  key. Blank Legacy IDs cannot be recovered from the data; filling them in would be
  invented values.
- Interpretation (not proven by the data): blank Legacy IDs are probably newer agencies
  that never received a legacy ID.
- Verification: 0 short IDs remain; all IDs match a valid format; 0 rows rejected;
  row count unchanged (4,369).
- Open question: 29 rows where the Legacy ID does not follow the usual NTD pattern
  (e.g. 5222 → 50519, Minnesota agencies). Left unchanged.


## Step 2: Drop empty columns
- Observation: 17 of 49 columns are blank in all 4,369 rows. All are "Questionable"
  flag columns (e.g. Operators Wages Questionable, Total Questionable).
- Decision: Drop any column that is blank in every row. Columns are detected
  automatically (two passes with awk), not from a hard-coded list; each dropped
  column name is written to logs/cleaning.log.
- Kept: Vehicle Revenue Hours Questionable (44 values: 27 "W", 17 "Q") and
  Any data questionable? (Yes/No, 624 blank) — these hold data and are needed
  for the questionable-data analysis.
- Not dropped: columns that are mostly zero (e.g. Operators Wages, 3,733 zeros).
  Zeros are real values — Reduced/Rural reporters report a single total in
  "Reduced Reporter Expenses" instead of the breakdown.
- Verification: 17 columns dropped; 33 columns remain (49 − 17 + 1 added flag);
  every row has 33 fields; row count unchanged (4,369).


## Step 3: Final verification
The script stops with an error (exit status 1) if any check fails, so a bad
cleaned file is never produced silently. Checks:
1. Cleaned file has exactly 33 columns.
2. Cleaned rows + rejected rows = raw rows (4,369 + 0 = 4,369), so no row is lost.
3. No blank NTD IDs; no NTD ID under 5 digits or numeric Legacy ID under 4 digits;
   "Legacy ID Missing" is only Yes/No and is Yes exactly when Legacy ID is blank.
4. No column is blank in every row.
- Tested: changing the expected column count to 34 made the script stop with
  "ERROR: Check: expected 34 columns, found 33" and exit status 1.

## Testing
- Missing input: renamed the raw CSV and ran the script → "ERROR: Raw file missing
  or empty", exit status 1, no cleaned file produced.
- Rerun safety: ran the script twice in a row → identical results (4,369 rows,
  33 columns, 0 rejected). Each run rebuilds from the raw file and starts a fresh log.