#!/bin/bash

host=$1


resdir=../results/${host}/

FLOPSFORMULA='$1 \* ($2 +1)/$3'

# times 2 cause mul and add
peak_flops=$( awk -F \  '{if ($2 == 32768){ print 2 * $1 * ($2 +1)/$3;}}'  < ${resdir}/basic_gpu_bench )

# times 2 cause read and write
# times 4 cause FP32
gpu_bandwidth=$( awk -F \  '{if ($2 == 0){ print 2 * $1 *  4 / $3;}}'  < ${resdir}/basic_gpu_bench )

interconnect_bandwidth=$(awk -F \  'BEGIN{maxv=0} {if ($2 == 0){bw = ($1 + $2 +1)*4*2 / $3; if (bw > maxv) {maxv = bw;}}} END{print maxv;}' < ${resdir}/gpu_stream )

uvm_bw=$(awk -F \  'BEGIN{maxv=0} {if ($2 == 0){bw = ($1 + $2 +1)*4*2 / $3; if (bw > maxv) {maxv = bw;}}} END{print maxv;}' < ${resdir}/gpu_uvm_basic)

echo peak_flops $peak_flops
echo gpu_bw $gpu_bandwidth
echo interconnect_bw $interconnect_bandwidth
echo uvm_bw $uvm_bw




