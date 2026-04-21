#!/bin/bash

BIN=./main
OUT=results.csv

ACCESS_MULT=16

TABLE_SIZES=(4 16 32 64 128)
FRACTIONS=(0.0001 0.0005 0.001 0.005 0.01 0.05 0.1)

# CSV header
echo "table_gb,fraction,access_mult,uvm_ms,explicit_ms" > $OUT

for T in "${TABLE_SIZES[@]}"; do
  for F in "${FRACTIONS[@]}"; do

    echo "Running: table=${T}GB fraction=${F}"

    OUTPUT=$($BIN $T $F $ACCESS_MULT)

    # Extract values
    UVM=$(echo "$OUTPUT" | grep "UVM time" | awk '{print $3}')
    EXPLICIT=$(echo "$OUTPUT" | grep "Explicit:" | awk '{print $2}')

    echo "$T,$F,$ACCESS_MULT,$UVM,$EXPLICIT" >> $OUT

  done
done

echo "Done. Results written to $OUT"
