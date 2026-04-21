#!/usr/bin/env bash

# Usage:
#   ./generate_graph.bash 15

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <scale>"
    exit 1
fi

SCALE="$1"
VERTICES=$((2**SCALE))

# Base project directory (assumes script is run from project root)
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRAPH500_DIR="$ROOT_DIR/graph500/nick_conv"
OUTPUT_DIR="$ROOT_DIR/graphs"

mkdir -p "$OUTPUT_DIR"

BIN_FILE="$OUTPUT_DIR/RMAT${SCALE}.bin"
GRAPH_FILE="$OUTPUT_DIR/RMAT${SCALE}.graph"

echo "Generating edge list for scale $SCALE..."
cd "$GRAPH500_DIR"
./../make-edgelist -s "$SCALE" -o "$BIN_FILE"

echo "Converting to Chaco format..."
./bin_to_chaco "$BIN_FILE" "$GRAPH_FILE" "$VERTICES"

echo "Done."
echo "Binary graph: $BIN_FILE"
echo "Chaco graph:  $GRAPH_FILE"
