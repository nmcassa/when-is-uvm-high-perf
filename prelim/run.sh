#!/usr/bin/env bash
# uvm_phase opening-figure experiment
# Phase 1: capacity sweep (the shelf + the wall + saturation)
# Phase 2: access-order discriminator (granularity vs LRF confound)
# Phase 3: independent transfer-size histograms
set -u

BIN=./uvm_phase
CAP=16
OVER=1.5
ACC=10000000
STAMP=$(date +%Y%m%d-%H%M%S)
OUT=results/$STAMP
mkdir -p "$OUT/logs"
SUM="$OUT/summary.tsv"
printf 'phase\tlabel\thot_gib\tpct_nominal\trawline\n' > "$SUM"

run() {
  # run <phase> <label> <hot> <iters> <logtag> [extra args...]
  local phase=$1 label=$2 h=$3 iters=$4 tag=$5; shift 5
  local gib pct log
  gib=$(awk -v c=$CAP -v h=$h 'BEGIN{printf "%.4f", c*h}')
  pct=$(awk -v h=$h 'BEGIN{printf "%.2f", 100*h}')
  log="$OUT/logs/${tag}.log"

  echo "[$(date +%H:%M:%S)] $phase $label  hot=$gib GiB (${pct}% nominal)  $*"
  timeout 1800 "$BIN" --cap $CAP --over $OVER --hot "$h" --cold 0 \
      --no-reset --accesses $ACC --iters "$iters" --per-iter "$@" \
      > "$log" 2>&1
  local rc=$?

  if [ $rc -eq 124 ]; then
    printf '%s\t%s\t%s\t%s\tTIMEOUT_1800S\n' "$phase" "$label" "$gib" "$pct" >> "$SUM"
    echo "  -> TIMEOUT (recorded as data point: A_m exceeded measurable range)"
    return
  elif [ $rc -ne 0 ]; then
    printf '%s\t%s\t%s\t%s\tEXIT_%d\n' "$phase" "$label" "$gib" "$pct" "$rc" >> "$SUM"
    echo "  -> nonzero exit $rc (see $log)"
    return
  fi

  local warm
  warm=$(awk -F, '$22=="-2"' "$log" | tail -1)
  [ -z "$warm" ] && warm=$(awk -F, 'NF>30' "$log" | tail -1)
  [ -z "$warm" ] && warm="NO_WARM_ROW_PARSED"
  printf '%s\t%s\t%s\t%s\t%s\n' "$phase" "$label" "$gib" "$pct" "$warm" >> "$SUM"
  echo "  -> $warm"
}

echo "=== PHASE 1a: the shelf (resident control region) ==="
for h in 0.60 0.70 0.80 0.85 0.90 0.93 0.95 0.96 0.965 0.970; do
  run P1 shelf "$h" 1 "p1_h${h}"
done

echo "=== PHASE 1b: knee localization (closes the continuity gap) ==="
for h in 0.9725 0.9750 0.9760 0.9765 0.9770 0.9775 0.9780 0.9785 0.9790 0.9795; do
  run P1 knee "$h" 1 "p1_h${h}"
done

echo "=== PHASE 1c: the hinge and saturation ==="
for h in 0.980 0.985 0.990 0.995 1.000; do
  run P1 hinge "$h" 1 "p1_h${h}"
done

echo "=== PHASE 2: access-order discriminator at fixed footprint ==="
# Granularity amplification should be order-insensitive; LRF thrashing should not.
# If the multiplier holds flat across these, the 47.6x asymmetry owns the effect.
for L in 1 8 64 512 4096; do
  run P2 "loc${L}" 0.985 1 "p2_loc${L}" --locality $L
done
run P2 noncontig 0.985 1 "p2_noncontig"           # default (non-contiguous) placement
run P2 contig    0.985 1 "p2_contig" --contiguous

echo "=== PHASE 3: independent transfer-size histograms ==="
for h in 0.980 0.990; do
  echo "[$(date +%H:%M:%S)] P3 size-hist hot=$h"
  timeout 1800 "$BIN" --cap $CAP --over $OVER --hot $h --cold 0 --contiguous \
      --no-reset --accesses $ACC --iters 1 --size-hist \
      > "$OUT/logs/p3_hist_h${h}.log" 2>&1
  echo "  -> exit $? ($OUT/logs/p3_hist_h${h}.log)"
done

echo
echo "DONE. Summary: $SUM"
echo "Logs:    $OUT/logs/"
column -t -s $'\t' "$SUM" 2>/dev/null || cat "$SUM"
