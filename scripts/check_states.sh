#!/usr/bin/env bash
# Usage: ./check_states.sh yourfile.csv
#in this project: ./scripts/check_states.sh data/raw/Operating_Expenses_by_Type_2020.csv
# Prints Agency and City (columns 1 and 2) for every row whose State (column 3)
# is not a valid two-letter code for a US state, DC, or a US territory (PR GU AS VI MP).
# Works with any standard awk (handles quoted fields that contain commas).

file="${1:-Operating_Expenses_by_Type_2020__1_.csv}"

if [[ ! -f "$file" ]]; then
  echo "File not found: $file" >&2
  exit 1
fi

awk '
BEGIN {
  n = split("AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC PR GU AS VI MP", s, " ")
  for (i = 1; i <= n; i++) valid[s[i]] = 1
}

# Split one CSV line into f[1..nf], respecting "quoted, fields" and "" escapes
function parse(line,    i, c, inq, cur) {
  nf = 0; cur = ""; inq = 0
  for (i = 1; i <= length(line); i++) {
    c = substr(line, i, 1)
    if (inq) {
      if (c == "\"") {
        if (substr(line, i + 1, 1) == "\"") { cur = cur "\""; i++ }
        else inq = 0
      } else cur = cur c
    } else if (c == "\"") inq = 1
    else if (c == ",") { f[++nf] = cur; cur = "" }
    else cur = cur c
  }
  f[++nf] = cur
}

{
  sub(/\r$/, "")
  if (NR == 1) next                      # skip header row
  parse($0)
  state = f[3]
  gsub(/^[ \t]+|[ \t]+$/, "", state)     # trim whitespace
  if (!(state in valid))
    printf "Line %d: %s | %s   (State: \"%s\")\n", NR, f[1], f[2], state
}' "$file"
