
#!/usr/bin/env bash
# Group records by State and Mode of Transportation.

set -euo pipefail

INPUT="${1:-data/clean/Operating_Expenses_expenses_clean.tsv}"
OUTDIR="data/output"
LOGDIR="logs"
OUTPUT="$OUTDIR/state_mode_grouped.tsv"
LOG="$LOGDIR/state_mode.log"

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: $INPUT not found. Run 02_clean.sh first." >&2
    exit 1
fi

if [[ ! -d "$OUTDIR" || ! -d "$LOGDIR" ]]; then
    echo "ERROR: Required output directories do not exist." >&2
    exit 1
fi

awk -F '\t' '
NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i == "State") state = i
        if ($i == "Mode") mode = i
    }

    if (!state || !mode) {
        print "ERROR: State or Mode column not found." > "/dev/stderr"
        exit 1
    }

    print "State\tMode"
    next
}
{
    key = $state "\t" $mode
    if (!seen[key]++) {
        print key
    }
}
' "$INPUT" > "$OUTPUT"

sort -t "$(printf '\t')" -k1,1 -k2,2 "$OUTPUT" -o "$OUTPUT"

echo "Records grouped by State and Mode." > "$LOG"
echo "Output: $OUTPUT" >> "$LOG"

echo "Grouping complete."
