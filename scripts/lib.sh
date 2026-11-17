#!/usr/bin/env bash
# Shared helpers sourced by every stage script.

# Resolve project root from this file's location (no hard-coded paths).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="$PROJECT_ROOT/data/raw"
CLEAN_DIR="$PROJECT_ROOT/data/clean"
OUTPUT_DIR="$PROJECT_ROOT/output"
LOG_DIR="$PROJECT_ROOT/logs"

RAW_FILE="$RAW_DIR/Operating_Expenses_by_Type_2020.csv"
ERROR_LOG="$LOG_DIR/errors.log"
CLEANING_LOG="$LOG_DIR/cleaning.log"

EXPECTED_FIELDS=53

log()  { printf '%s [INFO]  %s\n' "$(date '+%F %T')" "$*" | tee -a "$ERROR_LOG" >&2; }
warn() { printf '%s [WARN]  %s\n' "$(date '+%F %T')" "$*" | tee -a "$ERROR_LOG" >&2; }
die()  { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$*" | tee -a "$ERROR_LOG" >&2; exit 1; }

require_file() {
    [[ -f "$1" ]] || die "Required file not found: $1"
    [[ -r "$1" ]] || die "Required file not readable: $1"
    [[ -s "$1" ]] || die "Required file is empty: $1"
}

require_cmd() {
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || die "Required command not found: $c"
    done
}
