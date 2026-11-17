#!/usr/bin/env bash
# Runs the full workflow from raw data to analysis output.
# Usage: ./analyze.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

mkdir -p "$CLEAN_DIR" "$OUTPUT_DIR" "$LOG_DIR"
: > "$ERROR_LOG"   # fresh log each run so reruns are safe

trap 'die "Workflow failed at line $LINENO (exit $?)"' ERR

require_cmd awk sed grep sort uniq cut sha256sum
require_file "$RAW_FILE"

log "Raw file: $RAW_FILE ($(wc -l < "$RAW_FILE") lines)"
log "SHA-256: $(sha256sum "$RAW_FILE" | cut -d' ' -f1)"

"$PROJECT_ROOT/scripts/01_inspect.sh"
"$PROJECT_ROOT/scripts/02_clean.sh"
"$PROJECT_ROOT/scripts/03_analyze.sh"

log "Workflow completed successfully"
exit 0
