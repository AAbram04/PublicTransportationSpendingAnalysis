#!/usr/bin/env bash
# Find exact duplicate rows and repeated NTD ID + Mode + TOS combinations

set -euo pipefail

INPUT="${1:-data/clean/Operating_Expenses_expenses_clean.tsv}"
OUTDIR="data/ouput"
LOGDIR="logs"

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: $INPUT not found. Run 02_clean.sh first." >&2
    exit 1
fi
if [[ ! -d "$OUTDIR" || ! -d "$LOGDIR" ]]; then
    echo "ERROR: Create data/analysis and logs directories first." >&2
    exit 1
fi

EXACT="$OUTDIR/exact_duplicates.tsv"
KEYDUPS="$OUTDIR/duplicate_id_mode_tos.tsv"
LOG="$LOGDIR/duplicates.log"

exact_count=$(awk -F '\t' -v out="$EXACT" '
NR == 1 { print $0 > out; next }
seen[$0]++ { print $0 >> out; count++ }
END { print count + 0 }
' "$INPUT")

key_count=$(awk -F '\t' -v out="$KEYDUPS" '
NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    id = col["NTD ID"]; mode = col["Mode"]; tos = col["TOS"]
    if (!id || !mode || !tos) {
        print "ERROR: Required columns are missing." > "/dev/stderr"
        exit 2
    }
    print $0 > out
    next
}
{
    if ($id == "") next
    key = $id SUBSEP $mode SUBSEP $tos
    if (seen[key]++) { print $0 >> out; count++ }
}
END { print count + 0 }
' "$INPUT")

echo "Exact duplicate rows (extra copies): $exact_count" > "$LOG"
echo "Repeated NTD ID + Mode + TOS rows (extra copies): $key_count" >> "$LOG"
echo "Reports: $EXACT and $KEYDUPS" >> "$LOG"
echo "Duplicate checks complete."
