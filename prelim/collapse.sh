#!/usr/bin/env bash
# ============================================================================
# collapse.sh -- Multi-axis data-collapse experiment for the UVM scaling law.
#
#   Goal: test whether V_mig = U_blk * A(U_blk / C_eff) is a UNIVERSAL function
#   of the reduced footprint x = U_blk / C_eff, regardless of WHICH knob
#   (h, c, O, locality, pattern) generated that footprint.
#
#   Also collects:
#     - the time<->bytes link   T = T_0 + V_mig / B_eff   (all arms feed this)
#     - a --flops composition sweep (additive vs max())
#     - per-arm C_eff via an in-situ floor+bracket (kills the dperm-drift artifact)
#     - N independent process launches near the cliff for a C_eff error bar
#
#   No changes to uvm_phase.cu required. Bytes-only. No driver mods.
#
#   PERF NOTES (why this is fast):
#     * C_eff finding is cheap: it uses probe-scoped ACC/ITERS/TIMEOUT and a
#       trimmed floor(2)+bracket(4) ladder. The cliff LOCATION does not depend
#       on access count or warm-median iteration -- only on footprint vs
#       capacity -- so short probes find it just as well while post-cliff steps
#       stay cheap and a low probe TIMEOUT kills any too-deep step quickly.
#     * ARM O does NOT re-bracket C_eff per O. C_eff is a DEVICE constant; the
#       only O-dependence is the scratch buffer cudaMalloc(dperm, nGran*4).
#       With nGran = allocation pages = O*CAP/4096, that buffer = O*16 MiB, so
#         C_eff(O) = C_eff_ref - (16 MiB)*(O - O_ref).
#       Over O in [1.05,3.0] this shift is ~31 MiB (~0.2% of C_eff) -- below the
#       run-to-run C_eff jitter we error-bar in the cliff-reps block -- so an
#       empirical per-O bracket would burn hours resolving sub-noise structure.
#       Set CEFF_PER_O=1 to restore the old empirical per-O bracket.
#
#   Usage:   ./collapse.sh              # full run
#            ACC=5000000 ./collapse.sh  # faster/cheaper
#            REPS=3 ./collapse.sh       # fewer cliff repeats
#            CEFF_PER_O=1 ./collapse.sh # empirical per-O C_eff (slow)
# ============================================================================
set -u

# ---- config ----------------------------------------------------------------
BIN=${BIN:-./uvm_phase}
CAP=${CAP:-16}                 # GiB, --cap (fixed physical capacity model)
NOMINAL=${NOMINAL:-16}
ACC=${ACC:-10000000}           # accesses / iter (DATA points)
ITERS=${ITERS:-2}              # >=2 so we drop iter0 and take a warm median
REPS=${REPS:-1}                # independent launches per near-cliff point
TIMEOUT=${TIMEOUT:-1800}       # timeout for DATA points
GRAN=${GRAN:-4096}

# ---- C_eff-finder probe budget (cheap; location != accuracy of a data pt) --
PACC=${PACC:-2000000}          # accesses/iter while FINDING the cliff
PITERS=${PITERS:-2}            # min warm-able iters for probes
PTMO=${PTMO:-300}              # timeout for a single probe (kills deep steps)
CEFF_PER_O=${CEFF_PER_O:-0}    # 1 => empirical per-O bracket (old, slow)

# ---- dperm/analytic C_eff(O) correction ------------------------------------
# dperm = cudaMalloc(nGran*4), nGran = allocation pages = O*CAP_bytes/4096.
#   dperm(O) = O*CAP*(4/4096) bytes = O*CAP/1024 GiB.  With CAP=16 -> O*16 MiB.
# Correction relative to the reference O used to measure C_eff:
#   C_eff(O) = C_eff_ref - (dperm(O) - dperm(O_ref))
# DPERM_GIB_PER_O below is (CAP/1024) GiB per unit O = 16 MiB per O at CAP=16.
O_REF=${O_REF:-1.5}
DPERM_GIB_PER_O=$(awk -v cap="$CAP" 'BEGIN{printf "%.9f", cap/1024.0}')

OUT=results/collapse-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT/logs"
echo "output dir: $OUT"

# ---- uvm_phase CSV field map (1-based, matches your header) ----------------
# gpu(1),mode(2),O(3),h(4),c(5),cold_pattern(6),locality(7),...,
# iter(22),accesses(23),accPerThread(24),
# time_total_s(25),time_s(26),time_last_s(27),time_warm_s(28),
# Maccess_per_s(29),useful_GBs(30),
# unique_GiB(31),unique_64k_GiB(32),unique_blk_GiB(33),
# cold_acc(34),cold_blks(35),cold_blk_GiB(36),dcold_over_slack(37),
# htod_GiB(38),dtoh_GiB(39),mig_GiB(40),
# A_m_page(41),A_m_htod(42),A_m_64k(43),A_m_64k_htod(44),
# A_m_blk(45),A_m_blk_htod(46),...
F_ITER=22
F_TIME=26
F_UBLK=33          # unique_blk_GiB  == U_blk
F_UPAGE=31         # unique_GiB
F_HTOD=38
F_DTOH=39
F_MIG=40
F_AMBLKHTOD=46

# ============================================================================
# core: run one measurement, return the warm-median full CSV row on stdout.
#   args: <tag> <extra uvm_phase flags...>
#   Honors optional per-call overrides via env: M_ACC, M_ITERS, M_TMO.
# ============================================================================
measure() {
  local tag=$1; shift
  local log="$OUT/logs/${tag}.log"
  local m_acc=${M_ACC:-$ACC} m_iters=${M_ITERS:-$ITERS} m_tmo=${M_TMO:-$TIMEOUT}
  timeout "$m_tmo" "$BIN" --cap "$CAP" --granule "$GRAN" \
      --accesses "$m_acc" --iters "$m_iters" --per-iter "$@" > "$log" 2>&1
  local rc=$?
  if [ $rc -eq 124 ]; then echo "TIMEOUT"; return 1; fi
  if [ $rc -ne 0 ];   then echo "EXIT_$rc"; return 1; fi
  # warm per-iter rows: real rows (NF>30), iter>=1, median by mig_gib
  local row
  row=$(awk -F, -v fi=$F_ITER -v fm=$F_MIG \
            'NF>30 && $fi ~ /^[0-9]+$/ && $fi+0>=1 {print}' "$log" \
        | sort -t, -k${F_MIG},${F_MIG}g \
        | awk 'END{n=NR}{a[NR]=$0}END{if(n>0)print a[int((n+1)/2)]}')
  [ -z "$row" ] && row=$(awk -F, 'NF>30' "$log" | tail -1)
  [ -z "$row" ] && { echo "NO_ROW"; return 1; }
  echo "$row"
}

field() { printf '%s' "$1" | awk -F, -v k="$2" '{print $k}'; }

# ============================================================================
# C_eff finder: for a given (O, c, K, pattern), find the effective capacity
#   = the hot-fraction at which mig departs from the compulsory floor.
#   Returns "Ceff_GiB floor_GiB" on stdout.
#
#   FAST: probes use M_ACC=$PACC, M_ITERS=$PITERS, M_TMO=$PTMO (exported per
#   call), a 2-point floor and a 4-step coarse bracket that breaks on first
#   departure. This finds the cliff LOCATION cheaply; data points below use the
#   full ACC/ITERS/TIMEOUT.
# ============================================================================
find_ceff() {
  local otag=$1 O=$2 c=$3 K=$4 pat=$5
  local pflag=""; [ "$pat" = "seq" ] && pflag="--cold-pattern seq"
  local floorlog="$OUT/logs/ceff_${otag}.txt"
  : > "$floorlog"

  # (a) floor: average mig over sub-cliff hot fractions (2 points is enough:
  #     the floor is flat by construction)
  local fsum=0 fn=0 h row mig
  for h in 0.900 0.950; do
    row=$(M_ACC=$PACC M_ITERS=$PITERS M_TMO=$PTMO \
          measure "ceff_${otag}_f${h}" --over "$O" --hot "$h" --cold "$c" \
                  --locality "$K" $pflag --contiguous) || continue
    mig=$(field "$row" $F_MIG)
    echo "floor h=$h mig=$mig" >> "$floorlog"
    case "$mig" in ''|*[!0-9.]*) ;; *) fsum=$(awk -v a=$fsum -v b=$mig 'BEGIN{print a+b}'); fn=$((fn+1));; esac
  done
  local floor
  floor=$(awk -v s=$fsum -v n=$fn 'BEGIN{if(n>0)printf "%.4f",s/n; else print "NA"}')
  echo "floor_mean=$floor" >> "$floorlog"

  # (b) coarse bracket: first h whose mig exceeds floor*1.25 == departure.
  #     4 steps straddling the known cliff; break as soon as we depart so we
  #     never walk deep post-cliff.
  local tol ceff="NA"
  tol=$(awk -v f=$floor 'BEGIN{if(f=="NA")print "NA"; else printf "%.4f",f*1.25}')
  if [ "$tol" != "NA" ]; then
    for h in 0.965 0.972 0.9755 0.978; do
      row=$(M_ACC=$PACC M_ITERS=$PITERS M_TMO=$PTMO \
            measure "ceff_${otag}_b${h}" --over "$O" --hot "$h" --cold "$c" \
                    --locality "$K" $pflag --contiguous) || continue
      mig=$(field "$row" $F_MIG)
      echo "bracket h=$h mig=$mig" >> "$floorlog"
      case "$mig" in ''|*[!0-9.]*) continue;; esac
      # C_eff in GiB = h * CAP as long as still <= tol; break once departed
      if awk -v m=$mig -v t=$tol 'BEGIN{exit !(m<=t)}'; then
        ceff=$(awk -v h=$h -v cap=$CAP 'BEGIN{printf "%.4f",h*cap}')
      else
        break
      fi
    done
  fi
  echo "Ceff_GiB=$ceff" >> "$floorlog"
  echo "$ceff $floor"
}

# ============================================================================
# emit one collapse row: <arm> <knobval> then the derived + raw fields
# ============================================================================
COLLAPSE="$OUT/collapse.tsv"
printf 'arm\tknob\tO\th\tc\tK\tpattern\tceff_gib\tfloor_gib\tublk_gib\tupage_gib\tx_ublk_over_ceff\tmig_gib\thtod_gib\tdtoh_gib\ttime_s\tamblkhtod\tcsv\n' > "$COLLAPSE"

emit() {
  local arm=$1 knob=$2 O=$3 h=$4 c=$5 K=$6 pat=$7 ceff=$8 floor=$9 row=${10}
  local ublk upage mig htod dtoh tm amb x
  ublk=$(field "$row" $F_UBLK);  upage=$(field "$row" $F_UPAGE)
  mig=$(field "$row" $F_MIG);    htod=$(field "$row" $F_HTOD)
  dtoh=$(field "$row" $F_DTOH);  tm=$(field "$row" $F_TIME)
  amb=$(field "$row" $F_AMBLKHTOD)
  x=$(awk -v u="$ublk" -v ce="$ceff" 'BEGIN{if(ce!="NA"&&ce+0>0)printf "%.5f",u/ce; else print "NA"}')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$arm" "$knob" "$O" "$h" "$c" "$K" "$pat" \
    "$ceff" "$floor" "$ublk" "$upage" "$x" "$mig" "$htod" "$dtoh" "$tm" "$amb" "$row" \
    >> "$COLLAPSE"
}

# ============================================================================
# ARM H -- reference: vary hot fraction (your original axis)
# ============================================================================
echo "=== ARM H: hot-fraction reference (O=1.5,c=0,K=1) ==="
read HCEFF HFLOOR <<<"$(find_ceff H 1.5 0 1 rand)"
echo "  H: Ceff=$HCEFF floor=$HFLOOR"
for h in 0.940 0.960 0.970 0.9745 0.9750 0.9754 0.9755 0.9757 0.976 0.977 0.978 0.980 0.982 0.984; do
  row=$(measure "H_h${h}" --over 1.5 --hot "$h" --cold 0 --locality 1 --contiguous) \
    && emit H "$h" 1.5 "$h" 0 1 rand "$HCEFF" "$HFLOOR" "$row"
done

# ============================================================================
# ARM C -- grow footprint via the COLD stream at fixed sub-cliff hot set
# ============================================================================
echo "=== ARM C: cold-rate sweep (h=0.90,O=1.5,K=1) ==="
read CCEFF CFLOOR <<<"$(find_ceff C 1.5 0 1 rand)"   # cold measured at c=0 floor
echo "  C: Ceff=$CCEFF floor=$CFLOOR"
for c in 0.000 0.002 0.005 0.010 0.020 0.050 0.100 0.200; do
  row=$(measure "C_c${c}" --over 1.5 --hot 0.90 --cold "$c" --locality 1 --contiguous) \
    && emit C "$c" 1.5 0.90 "$c" 1 rand "$CCEFF" "$CFLOOR" "$row"
done

# ============================================================================
# ARM O -- oversubscription: enters ONLY via cold-pool size (dilutes reuse).
#   C_eff is a DEVICE constant; the ONLY O-dependence is the dperm scratch
#   buffer (= O*16 MiB at CAP=16). We measure C_eff ONCE (reuse H's device
#   value) and subtract the computable dperm delta per O. This shift is ~0.2%
#   of C_eff over the whole sweep (< run-to-run jitter), so an empirical per-O
#   bracket would cost hours to resolve sub-noise structure.
#   Set CEFF_PER_O=1 to restore the old empirical per-O bracket.
# ============================================================================
echo "=== ARM O: oversubscription sweep (h=0.90,c=0.02,K=1) ==="
OCEFF_REF=$HCEFF
OFLOOR_REF=$HFLOOR
for O in 1.05 1.10 1.25 1.50 2.00 3.00; do
  if [ "$CEFF_PER_O" = "1" ]; then
    read OCEFF OFLOOR <<<"$(find_ceff O${O} "$O" 0.02 1 rand)"
    echo "  O=$O: Ceff=$OCEFF floor=$OFLOOR (empirical per-O)"
  else
    OCEFF=$(awk -v c="$OCEFF_REF" -v O="$O" -v Oref="$O_REF" -v d="$DPERM_GIB_PER_O" \
      'BEGIN{ if(c=="NA"){print "NA"} else {printf "%.4f", c - d*(O-Oref)} }')
    OFLOOR=$OFLOOR_REF
    echo "  O=$O: Ceff=$OCEFF floor=$OFLOOR (analytic dperm, ${DPERM_GIB_PER_O} GiB/O)"
  fi
  row=$(measure "O_o${O}" --over "$O" --hot 0.90 --cold 0.02 --locality 1 --contiguous) \
    && emit O "$O" "$O" 0.90 0.02 1 rand "$OCEFF" "$OFLOOR" "$row"
done

# ============================================================================
# ARM K -- locality: shrink footprint at fixed access count (post-cliff h)
# ============================================================================
echo "=== ARM K: locality sweep (h=0.99,O=1.5,c=0.02) ==="
read KCEFF KFLOOR <<<"$(find_ceff K 1.5 0.02 1 rand)"
echo "  K: Ceff=$KCEFF floor=$KFLOOR"
for K in 1 2 4 8 16 64 256; do
  row=$(measure "K_k${K}" --over 1.5 --hot 0.99 --cold 0.02 --locality "$K" --contiguous) \
    && emit K "$K" 1.5 0.99 0.02 "$K" rand "$KCEFF" "$KFLOOR" "$row"
done

# ============================================================================
# ARM P -- adversarial: same footprint, seq vs rand cold stream (reuse dist.)
# ============================================================================
echo "=== ARM P: cold-pattern seq vs rand (h=0.90,O=1.5,c=0.05) ==="
read PCEFF PFLOOR <<<"$(find_ceff P 1.5 0.05 1 rand)"
echo "  P: Ceff=$PCEFF floor=$PFLOOR"
for pat in rand seq; do
  pflag=""; [ "$pat" = "seq" ] && pflag="--cold-pattern seq"
  row=$(measure "P_${pat}" --over 1.5 --hot 0.90 --cold 0.05 --locality 1 $pflag --contiguous) \
    && emit P "$pat" 1.5 0.90 0.05 1 "$pat" "$PCEFF" "$PFLOOR" "$row"
done

# ============================================================================
# CLIFF ERROR BAR -- N independent launches with varied seed near C_eff.
#   Gives run-to-run C_eff jitter so the "sharp at 0.1% of footprint" claim
#   carries an honest precision. Independent processes == fresh allocation.
# ============================================================================
echo "=== CLIFF: $REPS independent launches per near-cliff h ==="
CLIFF="$OUT/cliff_reps.tsv"
printf 'h\trep\tseed\tmig_gib\ttime_s\tublk_gib\tcsv\n' > "$CLIFF"
for h in 0.9750 0.9752 0.9754 0.9756 0.9758 0.9760; do
  for r in $(seq 1 "$REPS"); do
    seed=$((1000 + r * 7919))
    row=$(measure "cliff_h${h}_r${r}" --over 1.5 --hot "$h" --cold 0 \
                  --locality 1 --seed "$seed" --contiguous) || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$h" "$r" "$seed" \
      "$(field "$row" $F_MIG)" "$(field "$row" $F_TIME)" \
      "$(field "$row" $F_UBLK)" "$row" >> "$CLIFF"
  done
done

# ============================================================================
# FLOPS -- composition sweep: is T = T_c + V/B (additive) or max()?
#   One sub-cliff point (compute dominates) + one post-cliff (migration dominates).
# ============================================================================
echo "=== FLOPS: compute/migration composition ==="
FLOPS="$OUT/flops.tsv"
printf 'regime\th\tflops\ttime_s\tmig_gib\tmaccess_per_s\tcsv\n' > "$FLOPS"
F_MACC=29
for regime_h in "sub:0.90" "post:0.99"; do
  regime=${regime_h%%:*}; h=${regime_h##*:}
  for fl in 0 32 128 512 2048; do
    row=$(measure "flops_${regime}_f${fl}" --over 1.5 --hot "$h" --cold 0.02 \
                  --locality 1 --flops "$fl" --contiguous) || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$regime" "$h" "$fl" \
      "$(field "$row" $F_TIME)" "$(field "$row" $F_MIG)" \
      "$(field "$row" $F_MACC)" "$row" >> "$FLOPS"
  done
done

# ============================================================================
# summary
# ============================================================================
{
  echo "cap_GiB=$CAP"
  echo "accesses=$ACC  iters=$ITERS  reps=$REPS  granule=$GRAN"
  echo "probe: PACC=$PACC PITERS=$PITERS PTMO=$PTMO  CEFF_PER_O=$CEFF_PER_O"
  echo "dperm_correction: O_ref=$O_REF  ${DPERM_GIB_PER_O} GiB per unit O"
  echo "H_ceff=$HCEFF C_ceff=$CCEFF K_ceff=$KCEFF P_ceff=$PCEFF"
  echo "collapse_table=$COLLAPSE"
  echo "cliff_reps=$CLIFF"
  echo "flops_table=$FLOPS"
  echo
  echo "PRIMARY PLOT: column x_ublk_over_ceff (x, log) vs amblkhtod (y, log),"
  echo "  one marker per arm, from $COLLAPSE -- collapse => universal A(x)."
  echo "LINK PLOT:    mig_gib (x) vs time_s (y), all arms pooled => T0 + V/Beff."
} | tee "$OUT/meta.txt"

echo
echo "=== COLLAPSE TABLE ==="
column -t -s $'\t' "$COLLAPSE" 2>/dev/null | cut -c1-160 || cat "$COLLAPSE"
echo
echo "Done. Everything under: $OUT"
