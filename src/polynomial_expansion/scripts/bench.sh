#!/bin/bash


GPU_SIZES="`expr 16 \* 1024 \* 1024`"
OVERSUBSCRIBED_SIZES="`expr 32 \* 1024 \* 1024`"

DEGREES="0 1 16 "

OUTPUTDIR="../results/$(hostname)/"

mkdir -p ${OUTPUTDIR}


# This will load various environment variable.
# This is useful becasue memory amount are different on different machines.
. ../env/$(hostname)  

echo $GPU_SIZES

compile() {
    (
	cd ../cpu
	make
	cd ../cuda
	make
    )
}

basics() {
    hostname
    cat /proc/cpuinfo
    cat /proc/meminfo
    uname -a
    nvcc --version
    gcc --version
    
    deviceQuery
    UnifiedMemoryPerf
    nvbandwidth
}

#this assumes a basic call of a binary ($1)
#This runs on GPU_SIZES only if $2 is 'n' and on oversubscribed if $2 is 'y'
bench_generic() {
    bin=$1
    oversubscribed=$2

    if [[ "$oversubscribed" == "y" ]] ;
    then
	SIZES="$GPU_SIZES $OVERSUBSCRIBED_SIZES"
    fi
    if [[ "$oversubscribed" == "n" ]];
    then
	SIZES="$GPU_SIZES"
    fi
    
    for s in $SIZES;
    do
	for d in $DEGREES;
	do
	    $1 $s $d
	done
    done
}


bench_stream_configurations() {
    DEGREE_TEST=1
    N_TEST=`expr 1024 \* 1024 \* 1024`

    for nstream in 1 2 4 8 16 32;
    do
	for chunksize in `expr 512 \* 1024` `expr 1 \* 1024 \* 1024` `expr 2 \* 1024 \* 1024` `expr 4 \* 1024 \* 1024` `expr 8 \* 1024 \* 1024` `expr 16 \* 1024 \* 1024` `expr 32 \* 1024 \* 1024` `expr 64 \* 1024 \* 1024` `expr 128 \* 1024 \* 1024`;
	do
	    echo "Testing configuration nstream=${nstream} chunksize=${chunksize}"
	    ../cuda/polynomial_gpu_stream ${N_TEST} ${DEGREE_TEST} ${nstream} ${chunksize}
	done
    done
}

cuda_stream_wrapper() {
    ../cuda/polynomial_gpu_stream $1 $2 16 `expr 16 \* 1024 \* 1024`
}


basic_gpu_bench() {
    ../cuda/polynomial_gpu_excluding_transfer `expr 1 \* 1024 \* 1024 \* 1024` 0
    ../cuda/polynomial_gpu_excluding_transfer `expr 1 \* 1024 \* 1024 \* 1024` `expr 32 \* 1024`        
}

#basics | tee ${OUTPUTDIR}/basics

#compile 2>&1 | tee ${OUTPUTDIR}/compile

#bench_generic ../cpu/polynomial n 2>&1 | tee ${OUTPUTDIR}/cpu

#bench_generic ../cpu/polynomial_openmp y 2>&1 | tee ${OUTPUTDIR}/cpu_openmp

#bench_generic ../cuda/polynomial_gpu_basic n 2>&1 | tee ${OUTPUTDIR}/gpu_basic

#bench_generic ../cuda/polynomial_gpu_pinned n 2>&1 | tee ${OUTPUTDIR}/gpu_pinned

#basic_gpu_bench  2>&1 | tee ${OUTPUTDIR}/basic_gpu_bench

bench_generic ../cuda/polynomial_gpu_uvm_basic y 2>&1 | tee ${OUTPUTDIR}/gpu_uvm_basic

#bench_generic cuda_stream_wrapper y 2>&1 | tee ${OUTPUTDIR}/gpu_stream

#bench_stream_configurations 2>&1 | tee ${OUTPUTDIR}/gpu_stream_configurations
