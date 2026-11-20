#!/usr/bin/env bash
# clean the raw data into data/clean/expenses_clean.tsv
# Run from the project folder:  ./scripts/02_clean.sh
# Logs counts to logs/cleaning.log; invalid rows go to data/clean/rejected.tsv
set -euo pipefail

RAW="data/raw/Operating_Expenses_by_Type_2020.csv"
CLEAN="data/clean/expenses_clean.tsv"
TMP="data/clean/tmp.tsv"
MSG="data/clean/tmp.msg"
REJECTED="data/clean/rejected.tsv"
LOG="logs/cleaning.log"

if [ ! -f "scripts/02_clean.sh" ]; then
    echo "ERROR: run this script from the project folder: ./scripts/02_clean.sh" >&2
    exit 1
fi

mkdir -p data/clean logs
rm -f "$LOG" "$REJECTED" "$TMP" "$MSG"   # start fresh each run
touch "$REJECTED"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

# Check the input exists before doing anything
[ -s "$RAW" ] || fail "Raw file missing or empty: $RAW"
log "Raw file: $RAW ($(awk 'END { print NR - 1 }' "$RAW") data rows)"

# CSV -> TSV
# split on quotes, replace commas with tabs only outside quotes, drop the quote marks
grep -q '""' "$RAW" && fail "Raw file has escaped quotes; Step 0 cannot handle them"
grep -q "$(printf '\t')" "$RAW" && fail "Raw file already contains tabs"

awk -F'"' -v OFS='' '{ for (i = 1; i <= NF; i += 2) gsub(/,/, "\t", $i); print }' "$RAW" > "$CLEAN"

badrows=$(awk -F'\t' 'NF != 49 { n++ } END { print n + 0 }' "$CLEAN")
[ "$badrows" -eq 0 ] || fail "Step 0: $badrows rows do not have 49 fields"
log "Step 0 CSV->TSV: all $(awk 'END { print NR }' "$CLEAN") lines have 49 fields"

# 1: standardize NTD ID, Legacy NTD ID
awk -F'\t' -v OFS='\t' -v rej="$REJECTED" '
NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; L = col["Legacy NTD ID"]; N = col["NTD ID"]; print $0, "Legacy ID Missing"; next }
{
  if ($L ~ /^[0-9][0-9]?[0-9]?$/) { while (length($L) < 4) $L = "0" $L; padL++ }
  if ($N ~ /^[0-9][0-9]?[0-9]?[0-9]?$/) { while (length($N) < 5) $N = "0" $N; padN++ }
  if ($L == "") { miss = "Yes"; nmiss++ } else miss = "No"
  if ($L != "" && $L !~ /^[0-9][0-9][0-9][0-9]$/ && $L !~ /^[0-9][A-Z][0-9][0-9]$/ && $L !~ /^[0-9][A-Z][0-9][0-9]-[0-9][0-9][0-9]$/) { print "bad Legacy NTD ID", $0 > rej; bad++; next }
  if ($N !~ /^[0-9][0-9][0-9][0-9][0-9]$/ && $N !~ /^[0-9][A-Z][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9]$/ && $N !~ /^[A-Z][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9]$/) { print "bad NTD ID", $0 > rej; bad++; next }
  print $0, miss
}
END { print "Step 1 IDs: padded Legacy=" padL+0 ", padded NTD=" padN+0 ", missing Legacy (flagged)=" nmiss+0 ", rejected=" bad+0 > "/dev/stderr" }
' "$CLEAN" > "$TMP" 2> "$MSG" || fail "Step 1 awk failed"
mv "$TMP" "$CLEAN"
log "$(cat "$MSG")"

# 2. drop 100% blank columns
# FNR==NR is true only for the first file: pass 1 records which columns have a value,
# pass 2 prints only those columns
awk -F'\t' -v OFS='\t' '
FNR == NR { if (FNR > 1) for (i = 1; i <= NF; i++) if ($i != "") used[i] = 1; next }
FNR == 1  { for (i = 1; i <= NF; i++) if (!(i in used)) { print "Step 2 dropped empty column: " $i > "/dev/stderr"; d++ }
            print "Step 2 empty columns dropped: " d+0 > "/dev/stderr" }
{ out = ""; for (i = 1; i <= NF; i++) if (i in used) out = (out == "" ? $i : out OFS $i); print out }
' "$CLEAN" "$CLEAN" > "$TMP" 2> "$MSG" || fail "Step 2 awk failed"
mv "$TMP" "$CLEAN"
while IFS= read -r line; do log "$line"; done < "$MSG"

ncols=$(awk -F'\t' 'NR == 1 { print NF }' "$CLEAN")
badrows=$(awk -F'\t' -v n="$ncols" 'NF != n { b++ } END { print b + 0 }' "$CLEAN")
[ "$badrows" -eq 0 ] || fail "Step 2: $badrows rows do not have $ncols fields"
log "Step 2 columns remaining: $ncols"

# step 3: final verification
# any failed check stops the script with an error (exit 1)
EXPECTED_COLS=33
raw_rows=$(awk 'END { print NR - 1 }' "$RAW")
clean_rows=$(awk 'END { print NR - 1 }' "$CLEAN")
rej_rows=$(awk 'END { print NR }' "$REJECTED")
total_rows=$(awk 'END { print NR - 1 }' "$CLEAN" "$REJECTED")   # clean + rejected, minus 1 header

[ "$ncols" -eq "$EXPECTED_COLS" ] || fail "Check: expected $EXPECTED_COLS columns, found $ncols"
log "Check passed: $ncols columns"

[ "$total_rows" -eq "$raw_rows" ] || fail "Check: clean ($clean_rows) + rejected ($rej_rows) != raw ($raw_rows)"
log "Check passed: clean ($clean_rows) + rejected ($rej_rows) = raw ($raw_rows)"

problems=$(awk -F'\t' '
NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; L = col["Legacy NTD ID"]; N = col["NTD ID"]; M = col["Legacy ID Missing"]; next }
{
  if ($N == "")                          print "line " NR ": blank NTD ID"
  if ($N ~ /^[0-9][0-9]?[0-9]?[0-9]?$/)  print "line " NR ": NTD ID not padded: " $N
  if ($L ~ /^[0-9][0-9]?[0-9]?$/)        print "line " NR ": Legacy ID not padded: " $L
  if ($M != "Yes" && $M != "No")         print "line " NR ": bad Legacy ID Missing value: " $M
  if (($L == "") != ($M == "Yes"))       print "line " NR ": Legacy ID Missing flag does not match"
}' "$CLEAN")
[ -z "$problems" ] || { echo "$problems" >> "$LOG"; fail "Check: ID problems found (listed in log)"; }
log "Check passed: all IDs padded, no blank NTD IDs, Legacy ID Missing flag correct"

empty=$(awk -F'\t' 'NR > 1 { for (i = 1; i <= NF; i++) if ($i != "") used[i] = 1 }
                    END { for (i = 1; i <= NF; i++) if (!(i in used)) n++; print n + 0 }' "$CLEAN")
[ "$empty" -eq 0 ] || fail "Check: $empty empty columns remain"
log "Check passed: no empty columns remain"

rm -f "$MSG"
log "Rows after cleaning: $clean_rows; rejected: $rej_rows"
log "Cleaning finished: $CLEAN"