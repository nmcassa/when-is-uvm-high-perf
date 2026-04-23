#!/bin/bash

#set -e

EXEC=./cuda-pr
GRAPH_DIR=../../../graphs

OUT_CSV=data/NPS_results.csv

# Parameters to sweep
BFS_DEPTHS=(1 2 3 4)
#BFS_DEPTHS=(3)
UVM_MODES=(0 1)   # 0 = explicit, 1 = UVM

# Write CSV header
echo "scale,filename,nVtx,nonzero,BFS_DEPTH,use_uvm,AvgTime,NodesPerSec" > $OUT_CSV

for SCALE in {22..25}; do
    FILE="RMAT${SCALE}.graph"
    PATH_TO_GRAPH="${GRAPH_DIR}/${FILE}"

    for BFS in "${BFS_DEPTHS[@]}"; do
        for UVM in "${UVM_MODES[@]}"; do

            echo "Running SCALE=$SCALE BFS_DEPTH=$BFS UVM=$UVM..."

            # Run benchmark with args: [file] [nTry=1] [BFS_DEPTH] [use_uvm]
            OUTPUT=$($EXEC "$PATH_TO_GRAPH" 1 $BFS $UVM)

            # Extract the summary line
            SUMMARY=$(echo "$OUTPUT" | grep "filename:")
	    NPS_LINE=$(echo "$OUTPUT" | grep "Nodes-per-sec:")
	    NPS=$(echo "$NPS_LINE" | awk '{print $2}')

            # Parse fields
            FILENAME=$(echo "$SUMMARY" | awk '{print $2}')
            NVTX=$(echo "$SUMMARY" | awk '{print $4}')
            NONZERO=$(echo "$SUMMARY" | awk '{print $6}')
            AVGTIME=$(echo "$SUMMARY" | awk '{print $8}')

            # Write to CSV
            echo "$SCALE,$FILENAME,$NVTX,$NONZERO,$BFS,$UVM,$AVGTIME,$NPS" >> $OUT_CSV

            echo "  Done: AvgTime=$AVGTIME NodesPerSec=$NPS"
        done
    done
done

echo "All benchmarks complete. Results saved to $OUT_CSV"
