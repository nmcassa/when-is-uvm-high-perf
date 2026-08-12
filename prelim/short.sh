#!/usr/bin/env bash
set -u
BIN=./uvm_phase; CAP=16; ACC=10000000
OUT=results/$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT/logs"
SUM="$OUT/summary.tsv"; printf 'phase\tlabel\thot\tover\tpct\tcsv\n' > "$SUM"

run() { # run <phase> <label> <hot> <over> <tag> [extra...]
  local ph=$1 lb=$2 h=$3 ov=$4 tag=$5; shift 5
  local log="$OUT/logs/${tag}.log"
  echo "[$(date +%H:%M:%S)] $ph $lb hot=$h over=$ov $*"
  timeout 1800 "$BIN" --cap $CAP --over "$ov" --hot "$h" --cold 0 \
    --no-reset --accesses $ACC --iters 2 --per-iter "$@" > "$log" 2>&1
  local rc=$? row
  if [ $rc -eq 124 ]; then row="TIMEOUT_1800S"
  elif [ $rc -ne 0 ]; then row="EXIT_$rc"
  else
    row=$(awk -F, '$22=="-2"' "$log" | tail -1)
    [ -z "$row" ] && row=$(awk -F, 'NF>30' "$log" | tail -1)
    [ -z "$row" ] && row="NO_ROW"
  fi
  printf '%s\t%s\t%s\t%s\t%.2f\t%s\n' "$ph" "$lb" "$h" "$ov" \
    "$(awk -v h=$h 'BEGIN{print 100*h}')" "$row" >> "$SUM"
  echo "  -> $(echo "$row" | cut -c1-110)"
}

echo "=== 1a: shelf (small allocation: over = hot + 0.03) ==="
for h in 0.60 0.80 0.90 0.95 0.97; do
  run P1 shelf "$h" "$(awk -v h=$h 'BEGIN{printf "%.4f", h+0.03}')" "p1_h${h}" --contiguous
done

echo "=== 1a-check: same point, full allocation (confound control) ==="
run P1 shelf_ctl 0.95 1.5000 "p1_h0.95_over15" --contiguous

echo "=== 1b: knee (over=1.5, matches your existing hinge sweep) ==="
for h in 0.9750 0.9765 0.9780 0.9795; do
  run P1 knee "$h" 1.5000 "p1_h${h}" --contiguous
done

echo "=== 2: LRF-vs-granularity discriminator, fixed footprint ==="
for L in 1 64 4096; do
  run P2 "loc${L}" 0.985 1.5000 "p2_loc${L}" --contiguous --locality $L
done

echo; echo "Summary: $SUM"; column -t -s $'\t' "$SUM" 2>/dev/null || cat "$SUM"
