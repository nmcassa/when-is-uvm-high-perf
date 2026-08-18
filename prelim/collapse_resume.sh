#!/usr/bin/env bash
# ============================================================================
# collapse_resume.sh -- resume an interrupted collapse.sh run.
#
#   Latches onto an EXISTING results/collapse-*/collapse.tsv, figures out which
#   (arm,knob) rows are already present, and APPENDS only the missing work:
#     - remainder of ARM O (dperm-corrected C_eff, reusing measured H C_eff)
#     - ARM K, ARM P
#     - cliff_reps.tsv, flops.tsv  (created if absent, else skipped-if-complete)
#
#   Idempotent: re-running after another crash continues where it left off.
#
#   Usage:
#     RESUME_DIR=results/collapse-20260818-151549 ./collapse_resume.sh
#     # optional overrides:
#     K_CEFF=15.6080 K_FLOOR=14.8003 P_CEFF=15.6080 P_FLOOR=14.8003 \
#       RESUME_DIR=results/collapse-20260818-151549 ./collapse_resume.sh
#     # (setting K_CEFF/P_CEFF skips their find_ceff probes entirely)
# ============================================================================
set -u

# ---- locate the run to resume ----------------------------------------------
RESUME_DIR=${RESUME_DIR:-}
if [ -z "$RESUME_DIR" ]; then
  RESUME_DIR=$(ls -1d results/collapse-* 2>/dev/null | sort | tail -1)
fi
[ -z "$RESUME_DIR" ] && { echo "ERROR: no RESUME_DIR and none found under results/"; exit 1; }
COLLAPSE="$RESUME_DIR/collapse.tsv"
[ -f "$COLLAPSE" ] || { echo "ERROR: $COLLAPSE not found"; exit 1; }
OUT="$RESUME_DIR"
mkdir -p "$OUT/logs"
echo "resuming into: $OUT"

# ---- config (MUST match the original run) ----------------------------------
BIN=${BIN:-./uvm_phase}
CAP=${CAP:-16}
NOMINAL=${NOMINAL:-16}
ACC=${ACC:-10000000}
ITERS=${ITERS:-2}
REPS=${REPS:-1}
TIMEOUT=${TIMEOUT:-1800}
GRAN=${GRAN:-4096}

PACC=${PACC:-2000000}
PITERS=${PITERS:-2}
PTMO=${PTMO:-300}

O_REF=${O_REF:-1.5}
DPERM_GIB_PER_O=$(awk -v cap="$CAP" 'BEGIN{printf "%.9f", cap/1024.0}')

# ---- CSV field map ---------------------------------------------------------
F_ITER=22
F_TIME=26
F_UBLK=33
F_UPAGE=31
F_HTOD=38
F_DTOH=39
F_MIG=40
F_AMBLKHTOD=46
F_MACC=29

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

# ---- has this (arm,knob) row already been emitted? -------------------------
# columns 1 and 2 of collapse.tsv are arm and knob.
have_row() {
  local arm=$1 knob=$2
  awk -F'\t' -v a="$arm" -v k="$knob" \
    'NR>1 && $1==a && $2==k {found=1} END{exit !found}' "$COLLAPSE"
}

# ---- find_ceff (cheap probes; only used for K and P if not overridden) -----
find_ceff() {
  local otag=$1 O=$2 c=$3 K=$4 pat=$5
  local pflag=""; [ "$pat" = "seq" ] && pflag="--cold-pattern seq"
  local floorlog="$OUT/logs/ceff_${otag}.txt"
  : > "$floorlog"
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

# ---- emit one collapse row (APPENDS to existing tsv) -----------------------
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

# ---- recover H C_eff / floor from the existing file (H is complete) ---------
# take them from any existing H row (cols 8,9 = ceff_gib, floor_gib)
read HCEFF HFLOOR <<<"$(awk -F'\t' 'NR>1 && $1=="H"{print $8, $9; exit}' "$COLLAPSE")"
[ -z "$HCEFF" ] && { echo "WARN: no H rows found; falling back to 15.6080 14.8003"; HCEFF=15.6080; HFLOOR=14.8003; }
echo "recovered H: Ceff=$HCEFF floor=$HFLOOR"

# ============================================================================
# ARM O -- resume: only the missing O points (dperm-corrected C_eff)
# ============================================================================
echo "=== ARM O (resume): oversubscription sweep (h=0.90,c=0.02,K=1) ==="
OCEFF_REF=$HCEFF
for O in 1.05 1.10 1.25 1.50 2.00 3.00; do
  if have_row O "$O"; then echo "  O=$O: already present, skip"; continue; fi
  OCEFF=$(awk -v c="$OCEFF_REF" -v O="$O" -v Oref="$O_REF" -v d="$DPERM_GIB_PER_O" \
    'BEGIN{ if(c=="NA"){print "NA"} else {printf "%.4f", c - d*(O-Oref)} }')
  OFLOOR=$HFLOOR
  echo "  O=$O: Ceff=$OCEFF floor=$OFLOOR (analytic dperm)"
  row=$(measure "O_o${O}" --over "$O" --hot 0.90 --cold 0.02 --locality 1 --contiguous) \
    && emit O "$O" "$O" 0.90 0.02 1 rand "$OCEFF" "$OFLOOR" "$row"
done

# ============================================================================
# ARM K -- locality sweep (h=0.99,O=1.5,c=0.02)
# ============================================================================
echo "=== ARM K: locality sweep (h=0.99,O=1.5,c=0.02) ==="
KCEFF=${K_CEFF:-}; KFLOOR=${K_FLOOR:-}
if [ -z "$KCEFF" ]; then
  read KCEFF KFLOOR <<<"$(find_ceff K 1.5 0.02 1 rand)"
fi
echo "  K: Ceff=$KCEFF floor=$KFLOOR"
for K in 1 2 4 8 16 64 256; do
  if have_row K "$K"; then echo "  K=$K: already present, skip"; continue; fi
  row=$(measure "K_k${K}" --over 1.5 --hot 0.99 --cold 0.02 --locality "$K" --contiguous) \
    && emit K "$K" 1.5 0.99 0.02 "$K" rand "$KCEFF" "$KFLOOR" "$row"
done

# ============================================================================
# ARM P -- cold-pattern seq vs rand (h=0.90,O=1.5,c=0.05)
# ============================================================================
echo "=== ARM P: cold-pattern seq vs rand (h=0.90,O=1.5,c=0.05) ==="
PCEFF=${P_CEFF:-}; PFLOOR=${P_FLOOR:-}
if [ -z "$PCEFF" ]; then
  read PCEFF PFLOOR <<<"$(find_ceff P 1.5 0.05 1 rand)"
fi
echo "  P: Ceff=$PCEFF floor=$PFLOOR"
for pat in rand seq; do
  if have_row P "$pat"; then echo "  P=$pat: already present, skip"; continue; fi
  pflag=""; [ "$pat" = "seq" ] && pflag="--cold-pattern seq"
  row=$(measure "P_${pat}" --over 1.5 --hot 0.90 --cold 0.05 --locality 1 $pflag --contiguous) \
    && emit P "$pat" 1.5 0.90 0.05 1 "$pat" "$PCEFF" "$PFLOOR" "$row"
done

# ============================================================================
# CLIFF ERROR BAR -- create/append cliff_reps.tsv
# ============================================================================
echo "=== CLIFF: $REPS independent launches per near-cliff h ==="
CLIFF="$OUT/cliff_reps.tsv"
[ -f "$CLIFF" ] || printf 'h\trep\tseed\tmig_gib\ttime_s\tublk_gib\tcsv\n' > "$CLIFF"
cliff_have() {  # already have this h,rep pair?
  awk -F'\t' -v h="$1" -v r="$2" 'NR>1 && $1==h && $2==r {f=1} END{exit !f}' "$CLIFF"
}
for h in 0.9750 0.9752 0.9754 0.9756 0.9758 0.9760; do
  for r in $(seq 1 "$REPS"); do
    if cliff_have "$h" "$r"; then echo "  cliff h=$h r=$r: skip"; continue; fi
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
# FLOPS -- create/append flops.tsv
# ============================================================================
echo "=== FLOPS: compute/migration composition ==="
FLOPS="$OUT/flops.tsv"
[ -f "$FLOPS" ] || printf 'regime\th\tflops\ttime_s\tmig_gib\tmaccess_per_s\tcsv\n' > "$FLOPS"
flops_have() {  # already have this regime,flops pair?
  awk -F'\t' -v rg="$1" -v fl="$2" 'NR>1 && $1==rg && $3==fl {f=1} END{exit !f}' "$FLOPS"
}
for regime_h in "sub:0.90" "post:0.99"; do
  regime=${regime_h%%:*}; h=${regime_h##*:}
  for fl in 0 32 128 512 2048; do
    if flops_have "$regime" "$fl"; then echo "  flops $regime f=$fl: skip"; continue; fi
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
  echo "resumed_dir=$OUT"
  echo "cap_GiB=$CAP accesses=$ACC iters=$ITERS reps=$REPS granule=$GRAN"
  echo "probe: PACC=$PACC PITERS=$PITERS PTMO=$PTMO"
  echo "dperm_correction: O_ref=$O_REF ${DPERM_GIB_PER_O} GiB per unit O"
  echo "H_ceff=$HCEFF K_ceff=$KCEFF P_ceff=$PCEFF"
  echo "collapse_table=$COLLAPSE"
  echo "cliff_reps=$CLIFF"
  echo "flops_table=$FLOPS"
} | tee "$OUT/meta_resume.txt"

echo
echo "=== COLLAPSE TABLE (full) ==="
column -t -s $'\t' "$COLLAPSE" 2>/dev/null | cut -c1-160 || cat "$COLLAPSE"
echo
echo "Done. Everything under: $OUT"
