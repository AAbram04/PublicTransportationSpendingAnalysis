#!/usr/bin/env bash
# Runs the full workflow: inspect -> clean -> analyze
set -euo pipefail

./scripts/02_clean.sh
./scripts/03_analyze.sh