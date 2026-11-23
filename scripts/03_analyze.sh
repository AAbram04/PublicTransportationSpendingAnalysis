#!/usr/bin/env bash
# part 3: analyze the cleaned data

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

CLEAN="$ROOT/data/clean/expenses_clean.tsv"
OUT="$ROOT/output"
LOG="$ROOT/logs"

if [[ ! -r "$CLEAN" ]]; then
    echo "ERROR: cleaned dataset has not been found."
    echo "./scripts/02_clean.sh should be run first."
    exit 1
fi

mkdir -p "$OUT" "$LOG"

#Compare the vehical revenue hours with Primary UZA Population by state
awk -F '\t' -v OFS='\t' '
NR == 1 {
    for (i = 1; i <= NF; i++)
        column[$i] = i
    
    state_col = column["State"]
    hours_col = column["Vehicle Revenue Hours"]
    

    print "state", "records", "valid_hours", "invalid_hours", "total_vehical_revenue_hours",\
            "popluation", "hours_per_1000_people"
    
    next
}

{
    state = $state_col
    hours = $hours_col
    population = $8
    
    if (state == "")
        next
    
    records[state]++
    if(hours == "" || hours == "NA" || hours == "N/A" || hours == "NULL") {
        missing_hours[state]++
    }
    else if (hours !~ /^[0-9]+(\.[0-9]+)?$/) {
        invalid_hours[state]++
    }
    else {
        valid_hours[state]++
        total_hours[state] += hours
    }

    if (population ~ /^[0-9]+(\.[0-9]+)?$/ && population > 0) {
        state_population[state] = population
    }
}

END {
    for (state in records) {
        if (state_population[state] > 0) {
            population = state_population[state]
            rate = 1000 * total_hours[state] / population
        }
        else {
            population = ""
            rate = ""
        }

        printf "%s\t%d\t%d\t%d\t%d\t%.2f\t%s\t%s\n", state, records[state], \
        valid_hours[state] + 0, missing_hours[state] + 0, invalid_hours[state] + 0,\
        total_hours[state] + 0, population, rate
    }

}
' "$CLEAN" | {
    IFS= read -r header
    printf '%s\n' "$header"
    sort -t $'\t' -k1,1
} > "$OUT/hours_vs_population.tsv"


#Find unusual patterns
awk -F '\t' '
NR == 1 {
    for ( i = 1; i <= NF; i++)
        column[$i] = i

    next
}

{
    state[count] = $1
    population[count] = $7
    rate[count] = $8

    if (population[count] == "" || population[count] == 0) {
        missing_population[count] = 1
    }
    else {
        valid++
        sum += rate[count]
        sum_squares += rate[count] * rate[count]
    }

    count++
}

END {
    mean = valid ? sum / valid : 0

    variance = valid ? (sum_squares / valid - mean * mean) : 0
    standard_deviation = variance > 0 ? sqrt(variance) : 0

    print "Trends and Unusual Pattern Checks"
    print "--------------------------------"

    printf "States analyzed: %d\n", count
    printf "States with valid population rates: %d\n", valid
    printf "Mean hours per 1,000 people: %.4f\n", mean
    printf "Standard deviation: %.4f\n\n", standard_deviation

    print "Potentially Unusual Rates:"

    found = 0
    for ( i = 0; i < count; i++) {
        if (missing_population[i]) {
            print "  " state[i] ": population missing; excluded from comparison"
        }
        else if (standard_deviation > 0 && (rate[i] > mean + 2 * standard_deviation || rate[i] < mean - 2 * standard_deviation)) {
            printf " %s: %.4f hours per 1,000 people\n", state[i], rate[i]
            found++
        }

    }

    if (!found)
        print " None detected."
    
    print ""
    print "Population source: Primary UZA Population"
    print "Missing population values were excluded from comparisons."

}
' "$OUT/hours_vs_population.tsv" > "$OUT/trends_and_unusual_patterns.txt"

{
    echo "Analysis completed successfully."
    echo "Input: $CLEAN"
    echo "Population source: Primary UZA Population"
    echo "Raw CSV was not modified."
} > "$LOG/analysis.log"