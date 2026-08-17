#!/usr/bin/env bash
# ============================================================================
# divergence.sh -- Characterize the A_m divergence law near the UVM capacity
#                  boundary C_eff.
#
# Two phases:
#   Phase A (bisect C_eff): find the largest footprint with EXACTLY zero
#           migration (htod_GiB == 0). This anchors C_eff *independently* of
#           any A_m value, breaking the circularity in the old plot.py.
#
#   Phase B (log-spaced eps sweep): sample A_m at footprints geometrically
#           spaced in eps = (h - C_eff), from ~2 MiB to ~320 MiB past the
#           boundary. Log spacing is what lets us separate a power law
#           (A_m ~ eps^alpha) from a pole (A_m ~ 1/(eps_crit - eps)^beta).
#
# Design decisions specific to the divergence question:
#   * RESET EACH ITERATION (no --no-reset). Every point must be an independent,
#     clean A_m measurement; the --no-reset warm-mean produced the anomalous
#     0.9765 < 0.9750 inversion and would fake curvature near the boundary.
#   * --iters 4 and we keep ONLY the per-iter warm rows; we report the median
#     of the warm iterations per point, not a single noisy sample.
#   * cold=0, contiguous, locality=1: isolate pure capacity/replacement A_m.
#
# Output:
#   results/<stamp>/summary.tsv   -- one row per point, tab-separated, with the
#                                    raw uvm_phase CSV in the last column.
#   results/<stamp>/logs/*.log    -- full per-run output.
#   results/<stamp>/ceff.txt      -- the bisected C_eff (fraction and GiB).
#
# Feed summary.tsv to divergence_fit.py.
# ============================================================================
set -u

BIN=./uvm_phase
CAP=16                 # GiB, matches your P100 runs (--cap 16)
NOMINAL=16             # nominal capacity for %-of-nominal reporting
ACC=10000000           # accesses per iteration (same as short.sh)
ITERS=4                # >=4 so we can drop iter0 and take a warm median
OVER=1.5000            # allocation oversubscription; fixed so layout is stable
TIMEOUT=1800

OUT=results/$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT/logs"
SUM="$OUT/summary.tsv"
printf 'phase\tlabel\thot\tover\teps_mib\tpct\tmig_gib\tcsv\n' > "$SUM"

# ---- CSV field map (0-based), from uvm_phase.cu emit() --------------------
# 2=O 3=h 15=cap_GiB 16=hot_GiB 21=iter 25=time_s 37=htod_GiB 39=mig_GiB
#  40=A_m_page 41=A_m_htod 42=A_m_64k 46=A_m_blk_htod
F_ITER=22       # 1-based awk index for the "iter" column
F_MIG=40        # 1-based awk index for mig_GiB
# (awk is 1-based; these are the 0-based values above +1)

# run <phase> <label> <hot> <eps_mib> <tag> [extra...]
# Emits one summary row. Extracts the WARM MEDIAN across per-iter rows
# (iter>=1) rather than the aggregate, so each point is clean and independent.
run() {
  local ph=$1 lb=$2 h=$3 eps=$4 tag=$5; shift 5
  local log="$OUT/logs/${tag}.log"
  echo "[$(date +%H:%M:%S)] $ph $lb hot=$h eps=${eps}MiB $*"

  timeout "$TIMEOUT" "$BIN" --cap "$CAP" --over "$OVER" --hot "$h" --cold 0 \
    --accesses "$ACC" --iters "$ITERS" --per-iter "$@" > "$log" 2>&1
  local rc=$? row mig pct

  if   [ $rc -eq 124 ]; then row="TIMEOUT_${TIMEOUT}S"; mig="NA"
  elif [ $rc -ne 0 ];   then row="EXIT_$rc";            mig="NA"
  else
    # Warm per-iter rows: real data rows (NF>30) with iter column >= 1.
    # Take the row whose time_s is the MEDIAN of the warm set, so a single
    # jittery iteration can't dominate. Emit that whole CSV row.
    row=$(awk -F, -v fi=$F_ITER 'NF>30 && $fi ~ /^[0-9]+$/ && $fi+0>=1' "$log" \
          | sort -t, -k26,26g \
          | awk 'END{n=NR} {a[NR]=$0} END{if(n>0) print a[int((n+1)/2)]}')
    [ -z "$row" ] && row=$(awk -F, 'NF>30' "$log" | tail -1)
    [ -z "$row" ] && row="NO_ROW"
    mig=$(printf '%s' "$row" | awk -F, -v fm=$F_MIG '{print $fm}')
  fi

  pct=$(awk -v h="$h" -v n="$NOMINAL" -v c="$CAP" 'BEGIN{printf "%.4f",100*h*c/n}')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$ph" "$lb" "$h" "$OVER" "$eps" "$pct" "${mig:-NA}" "$row" >> "$SUM"
  echo "    -> mig=${mig} GiB  $(printf '%s' "$row" | cut -c1-90)"
}

# ============================================================================
# PHASE A: bisect C_eff (largest zero-migration footprint)
# ============================================================================
echo "=== Phase A: locate C_eff by zero-migration bisection ==="
# Coarse-to-fine hot fractions. mig_GiB flips from 0 to >0 across C_eff.
CEFF_GRID="0.9700 0.9720 0.9740 0.9750 0.9755 0.9760 0.9762 0.9764 0.9766 0.9768 0.9770 0.9775 0.9780"
for h in $CEFF_GRID; do
  run A ceff "$h" "-" "a_ceff_h${h}" --contiguous
done

# Determine C_eff = largest hot with mig_gib == 0 (column 7 of summary.tsv).
CEFF=$(awk -F'\t' '$1=="A" && $7!="NA" && ($7+0)==0 {c=$3} END{if(c!="")print c}' "$SUM")
CEFF_HI=$(awk -F'\t' -v c="$CEFF" '$1=="A" && $7!="NA" && ($7+0)>0 && ($3+0)>(c+0){if(m==""||($3+0)<(m+0))m=$3} END{print m}' "$SUM")
if [ -z "${CEFF:-}" ]; then
  echo "!! Phase A found no zero-migration point; widen CEFF_GRID downward." >&2
  CEFF=0.9758   # fallback to the old hand-picked bracket midpoint
fi
{
  echo "C_eff_fraction=$CEFF"
  echo "C_eff_GiB=$(awk -v c=$CEFF -v cap=$CAP 'BEGIN{printf "%.4f", c*cap}')"
  echo "first_migrating_fraction=${CEFF_HI:-NA}"
  echo "bracket_MiB=$(awk -v lo=$CEFF -v hi=${CEFF_HI:-$CEFF} -v cap=$CAP 'BEGIN{printf "%.1f",(hi-lo)*cap*1024}')"
} | tee "$OUT/ceff.txt"

# ============================================================================
# PHASE B: log-spaced eps = (h - C_eff) sweep
# ============================================================================
echo "=== Phase B: log-spaced amplification sweep past C_eff=$CEFF ==="
# eps in MiB, geometric-ish from 2 to 320. Dense near the boundary where the
# power-law and pole hypotheses diverge most.
EPS_MIB_LIST="2 4 6 8 12 16 24 32 48 64 96 128 192 256 320"
for eps in $EPS_MIB_LIST; do
  # h = C_eff + eps_MiB / (cap_GiB * 1024)   [eps in MiB, cap in GiB]
  h=$(awk -v c="$CEFF" -v e="$eps" -v cap="$CAP" 'BEGIN{printf "%.6f", c + e/(cap*1024)}')
  run B amp "$h" "$eps" "b_div_e${eps}" --contiguous
done

echo
echo "C_eff: $(cat "$OUT/ceff.txt" | tr '\n' ' ')"
echo "Summary: $SUM"
echo "Now run:  python3 divergence_fit.py \"$SUM\""
column -t -s $'\t' "$SUM" 2>/dev/null | cut -c1-160 || cat "$SUM"
