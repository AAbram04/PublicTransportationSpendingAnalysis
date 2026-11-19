#!/usr/bin/env bash
# part 2: clean the raw data into data/clean/expenses_clean.tsv
# Logs counts to logs/cleaning.log; invalid rows go to data/clean/rejected.tsv
set -euo pipefail

# paths based on where this script lives, so it works on anyone's computer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/data/raw/Operating_Expenses_by_Type_2020.csv"
CLEAN="$ROOT/data/clean/expenses_clean.tsv"
TMP="$ROOT/data/clean/tmp.tsv"
REJECTED="$ROOT/data/clean/rejected.tsv"
LOG="$ROOT/logs/cleaning.log"

mkdir -p "$ROOT/data/clean" "$ROOT/logs"
: > "$LOG"        # start a fresh log each run
: > "$REJECTED"   # start a fresh rejected file each run

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

# Check the input exists before doing anything
[ -s "$RAW" ] || fail "Raw file missing or empty: $RAW"
log "Raw file: ${RAW#"$ROOT"/} ($(wc -l < "$RAW" | tr -d ' ') lines)"

# 1. CSV to TSV
# Split on quotes; replace commas with tabs only outside quotes, drop the quote marks
grep -q '""' "$RAW" && fail "Raw file has escaped quotes; Step 0 cannot handle them"
grep -q "$(printf '\t')" "$RAW" && fail "Raw file already contains tabs"

awk -F'"' -v OFS='' '{ for (i = 1; i <= NF; i += 2) gsub(/,/, "\t", $i); print }' "$RAW" > "$CLEAN"

badrows=$(awk -F'\t' 'NF != 49' "$CLEAN" | wc -l | tr -d ' ')
[ "$badrows" -eq 0 ] || fail "Step 0: $badrows rows do not have 49 fields"
log "Step 0 CSV->TSV: all $(wc -l < "$CLEAN" | tr -d ' ') lines have 49 fields"

# 2. standardize NTD ID / Legacy NTD ID 
awk -F'\t' -v OFS='\t' -v rej="$REJECTED" '
NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; L = col["Legacy NTD ID"]; N = col["NTD ID"]; print $0, "Legacy ID Missing"; next }
{
  if ($L ~ /^[0-9][0-9]?[0-9]?$/) { $L = sprintf("%04d", $L); padL++ }
  if ($N ~ /^[0-9][0-9]?[0-9]?[0-9]?$/) { $N = sprintf("%05d", $N); padN++ }
  if ($L == "") { miss = "Yes"; nmiss++ } else miss = "No"
  if ($L != "" && $L !~ /^[0-9][0-9][0-9][0-9]$/ && $L !~ /^[0-9][A-Z][0-9][0-9]$/ && $L !~ /^[0-9][A-Z][0-9][0-9]-[0-9][0-9][0-9]$/) { print "bad Legacy NTD ID", $0 > rej; bad++; next }
  if ($N !~ /^[0-9][0-9][0-9][0-9][0-9]$/ && $N !~ /^[0-9][A-Z][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9]$/ && $N !~ /^[A-Z][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9]$/) { print "bad NTD ID", $0 > rej; bad++; next }
  print $0, miss
}
END { print "Step 1 IDs: padded Legacy=" padL+0 ", padded NTD=" padN+0 ", missing Legacy (flagged)=" nmiss+0 ", rejected=" bad+0 > "/dev/stderr" }
' "$CLEAN" > "$TMP" 2> "$TMP.msg" || fail "Step 1 awk failed"
mv "$TMP" "$CLEAN"
log "$(cat "$TMP.msg")"; rm -f "$TMP.msg"

log "Rows after cleaning: $(( $(wc -l < "$CLEAN") - 1 )); rejected: $(wc -l < "$REJECTED" | tr -d ' ')"
log "Cleaning finished: ${CLEAN#"$ROOT"/}"