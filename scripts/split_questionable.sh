#!/usr/bin/env bash
# Usage: ./split_questionable.sh input.csv [output_dir]
#
# Splits a CSV into two files based on the "Any data questionable?" column
# (a row is also treated as questionable if any of the individual
# "... Questionable" columns has a value in it):
#   <name>_clean.csv         rows with NO questionable data
#   <name>_questionable.csv  rows WITH questionable data
# Both files keep the original header row. Rows are copied exactly as they
# appear in the input. Output goes next to the input file unless you give
# an output_dir.

file="$1"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "Usage: $0 input.csv [output_dir]" >&2
  exit 1
fi

outdir="${2:-$(dirname "$file")}"
mkdir -p "$outdir" || exit 1

base="$(basename "$file")"
base="${base%.*}"
clean="$outdir/${base}_clean.csv"
quest="$outdir/${base}_questionable.csv"

awk -v clean="$clean" -v quest="$quest" '
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
  line = $0
  sub(/\r$/, "", line)
  parse(line)

  if (NR == 1) {                         # header row: find the questionable columns
    for (i = 1; i <= nf; i++) {
      h = tolower(f[i]); gsub(/^[ \t]+|[ \t]+$/, "", h)
      if (h == "any data questionable?") anycol = i
      else if (h ~ /questionable$/)      qcols[++nq] = i
    }
    if (!anycol && !nq) {
      print "Error: no questionable columns found in header." > "/dev/stderr"
      exit 2
    }
    print $0 > clean
    print $0 > quest
    next
  }

  isq = 0
  if (anycol) {
    v = tolower(f[anycol]); gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v == "yes") isq = 1
  }
  for (k = 1; k <= nq && !isq; k++) {
    v = f[qcols[k]]; gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v != "") isq = 1
  }

  if (isq) { print $0 > quest; nquest++ }
  else     { print $0 > clean; nclean++ }
}
END {
  printf "Clean rows:        %d  -> %s\n", nclean, clean
  printf "Questionable rows: %d  -> %s\n", nquest, quest
}' "$file"
