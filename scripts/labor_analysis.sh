#!/usr/bin/env bash
# labor cost analysis: Sameer 
# Questions: 
# How much is the cost of labor? Does it differ by mode and by state?
# Does labor explain why some modes cost more per hour?
set -euo pipefail

CLEAN="data/clean/expenses_clean.tsv"
OUT="output/labor"
LOG="logs/labor_analysis.log"
ROWS="$OUT/labor_rows.tsv"
BY_MODE="$OUT/labor_by_mode.tsv"
BY_STATE="$OUT/labor_by_state.tsv"
BY_MODE_STATE="$OUT/labor_by_mode_state.tsv"
REPORT="$OUT/labor_analysis.txt"
TMP="$OUT/tmp.tsv"
MSG="$OUT/tmp.msg"
TAB="$(printf '\t')"

if [ ! -f "scripts/labor_analysis.sh" ]; then
    echo "ERROR: run this script from the project folder: ./scripts/labor_analysis.sh" >&2
    exit 1
fi

mkdir -p "$OUT" logs
rm -f "$LOG" "$TMP" "$MSG"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

[ -s "$CLEAN" ] || fail "Cleaned file missing or empty: $CLEAN (run ./scripts/02_clean.sh first)"
log "Input: $CLEAN ($(awk 'END { print NR - 1 }' "$CLEAN") rows)"

# Every column this script uses must exist in the header
while IFS= read -r name; do
    awk -F'\t' -v name="$name" 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == name) found = 1; exit } END { exit !found }' "$CLEAN" \
        || fail "Required column missing: $name"
done <<'EOF'
Agency
State
Mode
TOS
Operators Wages
Other Salaries & Wages
Operators Paid Absences
Other Paid Absences
Fringe Benefits
Services
Fuel and Lube
Tires
Other Materials & Supplies
Utilities
Casualty and Liability
Taxes
Purchased Transportation in Report
Miscellaneous
Reduced Reporter  Expenses
Total
Vehicle Revenue Hours
Vehicle Revenue Hours Questionable
EOF
log "Check passed: all required columns present"

# 1. choose usable rows and compute labor
# Labor = Operators Wages + Other Salaries & Wages + Operators Paid Absences + Other Paid Absences + Fringe Benefits
# A row is used only if:
#   - TOS is directly operated (DO). (PT/TX/TN) the contractor's wages are inside "Purchased Transportation", so labor is hidden.
#   - labor > 0. 
#   - Total > 0 and Vehicle Revenue Hours > 0 
#   - the expense categories add up to Total (within $1)
awk -F'\t' -v OFS='\t' '
NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    print "Agency", "State", "Mode", "Labor", "Total", "Vehicle Revenue Hours", "Labor Share %", "Labor per Hour", "Total per Hour"
    next
}
{
    rows++
    labor = $col["Operators Wages"] + $col["Other Salaries & Wages"] + $col["Operators Paid Absences"] + $col["Other Paid Absences"] + $col["Fringe Benefits"]
    parts = labor + $col["Services"] + $col["Fuel and Lube"] + $col["Tires"] + $col["Other Materials & Supplies"] + $col["Utilities"] + $col["Casualty and Liability"] + $col["Taxes"] + $col["Purchased Transportation in Report"] + $col["Miscellaneous"] + $col["Reduced Reporter  Expenses"]
    total = $col["Total"] + 0
    hours = $col["Vehicle Revenue Hours"] + 0
    diff = parts - total
    if (diff < 0) diff = -diff

    if ($col["TOS"] != "DO")                              { notDO++; next }
    if (labor <= 0)                                       { nolabor++; next }
    if (total <= 0 || hours <= 0)                         { nototal++; next }
    if ($col["Vehicle Revenue Hours Questionable"] != "") { questionable++; next }
    if (diff > 1)                                         { mismatch++; next }

    used++
    printf "%s\t%s\t%s\t%.0f\t%.0f\t%.0f\t%.1f\t%.2f\t%.2f\n", $col["Agency"], $col["State"], $col["Mode"], labor, total, hours, 100 * labor / total, labor / hours, total / hours
}
END {
    print "Rows read: " rows + 0 > "/dev/stderr"
    print "Excluded, contracted service (TOS not DO): " notDO + 0 > "/dev/stderr"
    print "Excluded, no labor breakdown (Rural/Reduced/other reporters): " nolabor + 0 > "/dev/stderr"
    print "Excluded, Total or Vehicle Revenue Hours is 0: " nototal + 0 > "/dev/stderr"
    print "Excluded, Vehicle Revenue Hours flagged questionable: " questionable + 0 > "/dev/stderr"
    print "Excluded, expense categories do not add up to Total: " mismatch + 0 > "/dev/stderr"
    print "Rows used: " used + 0 > "/dev/stderr"
}
' "$CLEAN" > "$ROWS" 2> "$MSG" || { cat "$MSG" >&2; fail "Step 1 failed"; }
while IFS= read -r line; do log "Step 1 $line"; done < "$MSG"

used=$(awk 'END { print NR - 1 }' "$ROWS")
[ "$used" -gt 0 ] || fail "No usable rows for labor analysis"

# 2. group and summarize 
# rates come from group totals (sum of labor / sum of hours), so larger agencies count more
# Output columns: key(s), Rows, Labor $, Total $, Revenue Hours, Labor Share %, Labor per Hour, Non-Labor per Hour, Total per Hour
# Each table is sorted by Labor per Hour, highest first.

# By mode (key = column 3)
awk -F'\t' 'NR > 1 { L[$3] += $4; T[$3] += $5; H[$3] += $6; N[$3]++ }
END { for (g in N) printf "%s\t%d\t%.0f\t%.0f\t%.0f\t%.1f\t%.2f\t%.2f\t%.2f\n", g, N[g], L[g], T[g], H[g], 100 * L[g] / T[g], L[g] / H[g], (T[g] - L[g]) / H[g], T[g] / H[g] }' "$ROWS" \
    | sort -t "$TAB" -k7,7nr > "$TMP"
{ printf 'Mode\tRows\tLabor $\tTotal $\tRevenue Hours\tLabor Share %%\tLabor per Hour\tNon-Labor per Hour\tTotal per Hour\n'; cat "$TMP"; } > "$BY_MODE"

# By state (key = column 2)
awk -F'\t' 'NR > 1 { L[$2] += $4; T[$2] += $5; H[$2] += $6; N[$2]++ }
END { for (g in N) printf "%s\t%d\t%.0f\t%.0f\t%.0f\t%.1f\t%.2f\t%.2f\t%.2f\n", g, N[g], L[g], T[g], H[g], 100 * L[g] / T[g], L[g] / H[g], (T[g] - L[g]) / H[g], T[g] / H[g] }' "$ROWS" \
    | sort -t "$TAB" -k7,7nr > "$TMP"
{ printf 'State\tRows\tLabor $\tTotal $\tRevenue Hours\tLabor Share %%\tLabor per Hour\tNon-Labor per Hour\tTotal per Hour\n'; cat "$TMP"; } > "$BY_STATE"

# By mode + state (key = columns 3 and 2), sorted by mode, then labor per hour
awk -F'\t' 'NR > 1 { g = $3 "\t" $2; L[g] += $4; T[g] += $5; H[g] += $6; N[g]++ }
END { for (g in N) printf "%s\t%d\t%.0f\t%.0f\t%.0f\t%.1f\t%.2f\t%.2f\t%.2f\n", g, N[g], L[g], T[g], H[g], 100 * L[g] / T[g], L[g] / H[g], (T[g] - L[g]) / H[g], T[g] / H[g] }' "$ROWS" \
    | sort -t "$TAB" -k1,1 -k8,8nr > "$TMP"
{ printf 'Mode\tState\tRows\tLabor $\tTotal $\tRevenue Hours\tLabor Share %%\tLabor per Hour\tNon-Labor per Hour\tTotal per Hour\n'; cat "$TMP"; } > "$BY_MODE_STATE"
rm -f "$TMP"

log "Step 2 groups: $(awk 'END { print NR - 1 }' "$BY_MODE") modes, $(awk 'END { print NR - 1 }' "$BY_STATE") states, $(awk 'END { print NR - 1 }' "$BY_MODE_STATE") mode+state pairs"

# 3. verification
# each grouped table must add back up to the same labor, total and row count as the rows file
row_sums=$(awk -F'\t' 'NR > 1 { n++; l += $4; t += $5 } END { printf "%d %.0f %.0f", n, l, t }' "$ROWS")
for table in "$BY_MODE" "$BY_STATE"; do
    sums=$(awk -F'\t' 'NR > 1 { n += $2; l += $3; t += $4 } END { printf "%d %.0f %.0f", n, l, t }' "$table")
    [ "$sums" = "$row_sums" ] || fail "Check: $table totals ($sums) do not match rows ($row_sums)"
done
sums=$(awk -F'\t' 'NR > 1 { n += $3; l += $4; t += $5 } END { printf "%d %.0f %.0f", n, l, t }' "$BY_MODE_STATE")
[ "$sums" = "$row_sums" ] || fail "Check: $BY_MODE_STATE totals ($sums) do not match rows ($row_sums)"
log "Check passed: mode, state and mode+state tables add up to the rows used (rows, labor, total)"

bad=$(awk -F'\t' 'NR > 1 && ($7 < 0 || $7 > 100) { n++ } END { print n + 0 }' "$ROWS")
[ "$bad" -eq 0 ] || fail "Check: $bad rows have labor share outside 0-100%"
log "Check passed: every labor share is between 0% and 100%"

# 4.report 
{
    echo "LABOR COST ANALYSIS"
    echo "==================="
    echo "Labor = Operators Wages + Other Salaries & Wages + Operators Paid Absences"
    echo "        + Other Paid Absences + Fringe Benefits"
    echo "Rows used: $used directly operated (DO) agency + mode rows from agencies that"
    echo "report a full expense breakdown. Exclusions and counts: $LOG"
    echo "Rates are group totals divided by group hours (larger agencies weigh more)."
    echo

    awk -F'\t' 'NR > 1 { L += $4; T += $5; H += $6 } END {
        printf "OVERALL\n  Labor is %.1f%% of operating cost.\n  Labor per vehicle revenue hour: $%.2f   Total cost per hour: $%.2f\n", 100 * L / T, L / H, T / H }' "$ROWS"
    echo

    echo "BY MODE (sorted by labor per hour; * = fewer than 5 rows, treat with caution)"
    awk -F'\t' 'BEGIN {
        name["HR"] = "Heavy Rail";   name["LR"] = "Light Rail";        name["CR"] = "Commuter Rail"
        name["MB"] = "Bus";          name["RB"] = "Bus Rapid Transit"; name["CB"] = "Commuter Bus"
        name["DR"] = "Demand Resp."; name["FB"] = "Ferryboat";         name["SR"] = "Streetcar"
        name["TB"] = "Trolleybus";   name["VP"] = "Vanpool";           name["MG"] = "Monorail/Guideway"
        name["YR"] = "Hybrid Rail";  name["CC"] = "Cable Car";         name["IP"] = "Inclined Plane"
        name["TR"] = "Aerial Tram";  name["PB"] = "Publico";           name["AR"] = "Alaska Railroad"
        printf "  %-4s %-18s %5s %9s %10s %10s %10s\n", "Code", "Mode", "Rows", "Labor %", "Labor/hr", "Other/hr", "Total/hr"
    }
    NR > 1 { printf "  %-4s %-18s %5d %8.1f%% %10.2f %10.2f %10.2f%s\n", $1, ($1 in name ? name[$1] : "Other"), $2, $6, $7, $8, $9, ($2 < 5 ? " *" : "") }' "$BY_MODE"
    echo

    echo "BY STATE (states with at least 5 rows)"
    awk -F'\t' 'NR > 1 && $2 >= 5' "$BY_STATE" > "$TMP"
    echo "  Highest labor per hour:"
    head -5 "$TMP" | awk -F'\t' '{ printf "    %-3s $%8.2f/hr   labor share %5.1f%%   rows %d\n", $1, $7, $6, $2 }'
    echo "  Lowest labor per hour:"
    tail -5 "$TMP" | awk -F'\t' '{ printf "    %-3s $%8.2f/hr   labor share %5.1f%%   rows %d\n", $1, $7, $6, $2 }'
    echo "  Highest labor share of cost:"
    sort -t "$TAB" -k6,6nr "$TMP" | head -3 | awk -F'\t' '{ printf "    %-3s %5.1f%%\n", $1, $6 }'
    echo "  Lowest labor share of cost:"
    sort -t "$TAB" -k6,6n "$TMP" | head -3 | awk -F'\t' '{ printf "    %-3s %5.1f%%\n", $1, $6 }'
    rm -f "$TMP"
    echo

    echo "DOES LABOR EXPLAIN WHY SOME MODES COST MORE PER HOUR?"
    echo "  Each mode (5+ rows) compared with Bus (MB):"
    awk -F'\t' 'NR > 1 && $1 == "MB" { bl = $7; bt = $9 }
        NR > 1 && $2 >= 5 { k++; code[k] = $1; lab[k] = $7; tot[k] = $9 }
        END {
            for (i = 1; i <= k; i++) {
                if (code[i] == "MB") { printf "    %-3s baseline: $%.2f/hr total, $%.2f/hr labor\n", code[i], bt, bl; continue }
                dt = tot[i] - bt; dl = lab[i] - bl
                if (dt > 0) printf "    %-3s costs $%.2f/hr more than bus; labor accounts for $%.2f/hr of that (%.0f%%)\n", code[i], dt, dl, 100 * dl / dt
                else        printf "    %-3s costs $%.2f/hr less than bus; labor is $%.2f/hr less\n", code[i], -dt, -dl
            }
        }' "$BY_MODE"
    awk -F'\t' 'NR > 1 { x = $8; y = $9; n++; sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y }
        END { printf "  Correlation between labor per hour and total cost per hour (all %d rows): %.2f\n", n, (n * sxy - sx * sy) / sqrt((n * sxx - sx * sx) * (n * syy - sy * sy)) }' "$ROWS"
    echo "  (1.00 = they rise together exactly, 0 = no relationship)"
} > "$REPORT"

rm -f "$MSG"
log "Report: $REPORT"
log "Labor analysis finished"