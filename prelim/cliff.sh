#!/usr/bin/env bash
# ============================================================================
# cliff.sh -- Measure the UVM capacity cliff and effective boundary C_eff in
#             MIGRATED BYTES (not time), and gather a log-spaced excess-
#             migration sweep for the divergence-exponent hook.
#
# PMBS Late-Breaking framing:
#   SOLID result  : a sharp, sub-nominal effective capacity C_eff, and a
#                   ~3-4x migration jump across ~0.1% of footprint.
#   EARLY hook    : excess migration V_ex(h) = mig(h) - floor rises super-
#                   linearly as h -> C_eff+ ; power-law vs pole is preliminary.
#
# Why bytes, not time:
#   * mig (htod+dtoh GiB) is immune to the fault-batching / fault-duplicate
#     opacity that fault-count telemetry suffers from.
#   * Under --reset every timed iteration starts cold, so there is a COMPULSORY
#     migration FLOOR (~ resident working set). "Zero migration" is NOT
#     attainable; C_eff is defined as the DEPARTURE from that floor.
#
# Design (matches your working setup):
#   --cap 16 --over 1.5 --cold 0 --contiguous --reset --locality 1 --flops 0
#   --iters 3, per-iter, take the WARM MEDIAN mig per point (drop iter 0).
#
# Output:
#   results/<stamp>/summary.tsv   tab-separated; last col = raw uvm_phase CSV
#   results/<stamp>/logs/*.log
#   results/<stamp>/meta.txt      cap, nominal, floor estimate, notes
#
# Feed summary.tsv to cliff_fit.py.
# ============================================================================
set -u

BIN=./uvm_phase
CAP=16                 # GiB, --cap
NOMINAL=16             # GiB, for %-of-nominal reporting
OVER=1.5000            # allocation oversubscription (fixed -> stable layout)
ACC=10000000           # accesses / iter
ITERS=3                # >=2 so we can drop iter0 and take a warm median
TIMEOUT=1800

OUT=results/$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT/logs"
SUM="$OUT/summary.tsv"
printf 'phase\tlabel\thot\tover\teps_mib\tpct\tmig_gib\tcsv\n' > "$SUM"

# ---- uvm_phase CSV field map (1-based for awk) ----------------------------
# header: ...,iter(22),...,time_s(26),...,htod_GiB(38),dtoh_GiB(39),mig_GiB(40),...
F_ITER=22
F_MIG=40
F_TIME=26

# run <phase> <label> <hot> <eps_mib|-> <tag> [extra...]
# Emits one summary row using the WARM-MEDIAN per-iter row (iter>=1), so a
# single jittery iteration cannot dominate. eps_mib is metadata only.
run() {
  local ph=$1 lb=$2 h=$3 eps=$4 tag=$5; shift 5
  local log="$OUT/logs/${tag}.log"
  echo "[$(date +%H:%M:%S)] $ph $lb hot=$h eps=${eps} $*"

  timeout "$TIMEOUT" "$BIN" --cap "$CAP" --over "$OVER" --hot "$h" --cold 0 \
    --accesses "$ACC" --iters "$ITERS" --per-iter "$@" > "$log" 2>&1
  local rc=$? row mig pct

  if   [ $rc -eq 124 ]; then row="TIMEOUT_${TIMEOUT}S"; mig="NA"
  elif [ $rc -ne 0 ];   then row="EXIT_$rc";            mig="NA"
  else
    # warm per-iter rows: real rows (NF>30) with iter >= 1; median by mig_gib.
    row=$(awk -F, -v fi=$F_ITER -v fm=$F_MIG \
              'NF>30 && $fi ~ /^[0-9]+$/ && $fi+0>=1 {print}' "$log" \
          | sort -t, -k${F_MIG},${F_MIG}g \
          | awk 'END{n=NR} {a[NR]=$0} END{if(n>0) print a[int((n+1)/2)]}')
    [ -z "$row" ] && row=$(awk -F, 'NF>30' "$log" | tail -1)
    [ -z "$row" ] && row="NO_ROW"
    mig=$(printf '%s' "$row" | awk -F, -v fm=$F_MIG '{print $fm}')
  fi

  pct=$(awk -v h="$h" -v n="$NOMINAL" -v c="$CAP" 'BEGIN{printf "%.4f",100*h*c/n}')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$ph" "$lb" "$h" "$OVER" "$eps" "$pct" "${mig:-NA}" "$row" >> "$SUM"
  echo "    -> mig=${mig} GiB   $(printf '%s' "$row" | cut -c1-80)"
}

# ============================================================================
# PHASE F: establish the COMPULSORY MIGRATION FLOOR (well below the boundary)
#   These points should all report a flat, low mig (~ resident working set).
#   Their mean defines the floor that C_eff departs from.
# ============================================================================
echo "=== Phase F: compulsory-migration floor (sub-boundary) ==="
for h in 0.9400 0.9500 0.9600 0.9650 0.9700 0.9720 0.9740; do
  run F floor "$h" "-" "f_h${h}" --contiguous
done

# ============================================================================
# PHASE A: fine bracket around the departure point C_eff
#   Dense linear grid straddling ~0.9750. The DEPARTURE from the floor
#   (first point whose mig exceeds floor + tolerance) brackets C_eff.
# ============================================================================
echo "=== Phase A: fine C_eff bracket ==="
for h in 0.9745 0.9748 0.9750 0.9751 0.9752 0.9753 0.9754 0.9755 0.9757; do
  run A ceff "$h" "-" "a_h${h}" --contiguous
done

# ---- estimate floor + provisional C_eff for Phase B spacing --------------
FLOOR=$(awk -F'\t' '$1=="F" && $7!="NA"{s+=$7;n++} END{if(n>0)printf "%.4f",s/n}' "$SUM")
[ -z "$FLOOR" ] && FLOOR=15.6
# tolerance: 25% above the floor counts as "departed"
TOL=$(awk -v f="$FLOOR" 'BEGIN{printf "%.4f", f*1.25}')
# provisional C_eff = largest hot whose mig <= TOL (from F and A phases)
CEFF=$(awk -F'\t' -v tol="$TOL" \
        '($1=="F"||$1=="A") && $7!="NA" && ($7+0)<=tol {c=$3} END{print c}' "$SUM")
[ -z "$CEFF" ] && CEFF=0.9752
{
  echo "cap_GiB=$CAP"
  echo "nominal_GiB=$NOMINAL"
  echo "over=$OVER"
  echo "floor_GiB=$FLOOR"
  echo "departure_tolerance_GiB=$TOL"
  echo "provisional_Ceff_fraction=$CEFF"
  echo "provisional_Ceff_GiB=$(awk -v c=$CEFF -v cap=$CAP 'BEGIN{printf "%.4f",c*cap}')"
  echo "note=Ceff is the DEPARTURE from the compulsory floor, not a zero-migration point."
} | tee "$OUT/meta.txt"

# ============================================================================
# PHASE B: log-spaced excess-migration sweep past C_eff (the exponent hook)
# ============================================================================
echo "=== Phase B: log-spaced sweep past provisional C_eff=$CEFF ==="
EPS_MIB_LIST="2 3 4 6 8 12 16 24 32 48 64 96 128"
for eps in $EPS_MIB_LIST; do
  # h = C_eff + eps_MiB / (cap_GiB * 1024)
  h=$(awk -v c="$CEFF" -v e="$eps" -v cap="$CAP" 'BEGIN{printf "%.6f", c + e/(cap*1024)}')
  run B amp "$h" "$eps" "b_e${eps}" --contiguous
done

echo
echo "floor ~= ${FLOOR} GiB ; provisional C_eff = ${CEFF} ($(awk -v c=$CEFF -v cap=$CAP 'BEGIN{printf "%.3f",c*cap}') GiB)"
echo "Summary: $SUM"
echo "Now run:  python3 cliff_fit.py \"$SUM\""
column -t -s $'\t' "$SUM" 2>/dev/null | cut -c1-140 || cat "$SUM"
