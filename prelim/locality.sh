BASE=10000000
for L in 1 4 16 64 256; do
  ACC=$(( BASE * L ))
  echo "=== locality $L, accesses $ACC ==="
  timeout 1800 ./uvm_phase --cap 16 --over 1.5 --hot 0.985 --cold 0 --contiguous \
    --no-reset --accesses $ACC --iters 2 --per-iter --locality $L
done
