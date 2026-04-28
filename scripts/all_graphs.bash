#!/usr/bin/env bash

# File: prepare_pr_graphs.sh
# Purpose:
#   Generate all RMAT graphs needed by run_pr_benchmark.sh
#
# Usage:
#   ./prepare_pr_graphs.sh
#   ./prepare_pr_graphs.sh 22 25

set -euo pipefail

GEN_SCRIPT="generate_graph.bash"

# Default scale range matches run_pr_benchmark.sh
START_SCALE="${1:-22}"
END_SCALE="${2:-25}"

if [ "$START_SCALE" -gt "$END_SCALE" ]; then
    echo "Error: start scale must be <= end scale"
    exit 1
fi

echo "Generating graphs for scales $START_SCALE through $END_SCALE"
echo

for SCALE in $(seq "$START_SCALE" "$END_SCALE"); do
    echo "======================================"
    echo "Creating RMAT${SCALE}.graph"
    echo "======================================"

    bash "$GEN_SCRIPT" "$SCALE"

    echo
done

echo "All requested graphs generated."
