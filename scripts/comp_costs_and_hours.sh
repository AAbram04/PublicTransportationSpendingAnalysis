#!/usr/bin/env bash
# Prepare chart data comparing revenue hours with operating cost per hour.
# Run after 04_state_mode.sh.

set -euo pipefail

INPUT="${1:-data/clean/Operating_Expenses_expenses_clean.tsv}"
OUTDIR="data/output"
LOGDIR="logs"
OUTPUT="$OUTDIR/cost_vs_hours_points.tsv"
LOG="$LOGDIR/cost_vs_hours.log"

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: $INPUT not found. Run 04_state_mode.sh first." >&2
    exit 1
fi

awk -F '\t' '
NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    state = col["State"]
    mode = col["Mode"]
    hours = col["Valid Revenue Hours"]
    rate = col["Cost per Revenue Hour"]
    if (!state || !mode || !hours || !rate) {
        print "ERROR: Required summary columns are missing." > "/dev/stderr"
        exit 1
    }
    print "State\tMode\tVehicle Revenue Hours\tCost per Vehicle Revenue Hour"
    next
}
$hours > 0 && $rate > 0 {
    print $state "\t" $mode "\t" $hours "\t" $rate
    count++
}
END { print "Chart points created: " count + 0 > "/dev/stderr" }
' "$INPUT" > "$OUTPUT"

point_count=$(awk 'END {print NR - 1}' "$OUTPUT")
echo "Chart points created: $point_count" > "$LOG"
echo "Chart data: $OUTPUT" >> "$LOG"
echo "Chart data complete."
