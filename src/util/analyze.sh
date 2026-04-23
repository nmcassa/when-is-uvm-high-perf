#!/bin/sh

cd $HOME/ShMemColoring/src/util

#GRAPHPATH=$1
GRAPHNAME=`basename $GRAPHPATH`
OUTDIR=analysis/

mkdir -p $OUTDIR

#####################CACHE FRIENDLINESS#######################


OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_8_64_512K
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 cache_capacity=524288 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_8_64_32K
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 cache_capacity=32768 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_64_64_512K
if [ ! -f ${OUTFILE} ]
then
    datasize=64 CACHELINE=64 cache_capacity=524288 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_64_64_32K
if [ ! -f ${OUTFILE} ]
then
    datasize=64 CACHELINE=64 cache_capacity=32768 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_4_64_512K
if [ ! -f ${OUTFILE} ]
then
    datasize=4 CACHELINE=64 cache_capacity=524288 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_4_64_32K
if [ ! -f ${OUTFILE} ]
then
    datasize=4 CACHELINE=64 cache_capacity=32768 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_4_64_256K
if [ ! -f ${OUTFILE} ]
then
    datasize=4 CACHELINE=64 cache_capacity=262144 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_8_64_256K
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 cache_capacity=262144 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_16_64_256K
if [ ! -f ${OUTFILE} ]
then
    datasize=16 CACHELINE=64 cache_capacity=262144 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_32_64_256K
if [ ! -f ${OUTFILE} ]
then
    datasize=32 CACHELINE=64 cache_capacity=262144 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_32_64_20M
if [ ! -f ${OUTFILE} ]
then
    datasize=32 CACHELINE=64 cache_capacity=20971520 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_16_64_20M
if [ ! -f ${OUTFILE} ]
then
    datasize=16 CACHELINE=64 cache_capacity=20971520 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_8_64_20M
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 cache_capacity=20971520 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_4_64_20M
if [ ! -f ${OUTFILE} ]
then
    datasize=4 CACHELINE=64 cache_capacity=20971520 ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi

exit

#####################BASIC PROPERTIES#######################

OUTFILE=${OUTDIR}/${GRAPHNAME}_properties
if [ ! -f ${OUTFILE} ]
then
    ./graphprop $GRAPHPATH > $OUTFILE
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_rowdegree
if [ ! -f ${OUTFILE} ]
then
    ./rowdegree $GRAPHPATH > $OUTFILE
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_coldegree
if [ ! -f ${OUTFILE} ]
then
    ./coldegree $GRAPHPATH > $OUTFILE
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_degree.png
if [ ! -f ${OUTFILE} ]
then
    echo "set logscale y; set key top left; set xlabel 'vertex'; set ylabel 'degree'; set terminal png; set output '${OUTFILE}'; plot '${OUTDIR}/${GRAPHNAME}_rowdegree' t 'row degree', '${OUTDIR}/${GRAPHNAME}_coldegree' t 'column degree'" | gnuplot
fi

#####################TRACE#######################

OUTFILE=${OUTDIR}/${GRAPHNAME}_plot_2048.png
if [ ! -f ${OUTFILE} ]
then
    ./plot ${GRAPHPATH} ${GRAPHNAME} 2048
    convert ${GRAPHNAME}.pgm ${OUTFILE}
    rm ${GRAPHNAME}.pgm
fi

#####################VECTOR_ACCESS#######################

OUTFILE=${OUTDIR}/${GRAPHNAME}_vector_access_8_64
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 ./vector_access $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_vector_access_8_8
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=8 ./vector_access $GRAPHPATH > ${OUTFILE}
fi


OUTFILE=${OUTDIR}/${GRAPHNAME}_spmv_access_8_64_512K
if [ ! -f ${OUTFILE} ]
then
    datasize=8 CACHELINE=64 cache_capacity=524288 ./spmv_access $GRAPHPATH > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_spmv_access_1_1_4K
if [ ! -f ${OUTFILE} ]
then
    datasize=1 CACHELINE=1 cache_capacity=4096 ./spmv_access $GRAPHPATH > ${OUTFILE}
fi

exit


#####################REGISTER BLOCKING#######################

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC8
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 8 8 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC4
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 8 4 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC2
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 8 2 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC1
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 8 1 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC8
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 4 8 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC4
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 4 4 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC2
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 4 2 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC1
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 4 1 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC8
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 2 8 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC4
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 2 4 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC2
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 2 2 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC1
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 2 1 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC8
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 1 8 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC4
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 1 4 > ${OUTFILE}
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC2
if [ ! -f ${OUTFILE} ]
then
    ./block $GRAPHPATH 1 2 > ${OUTFILE}
fi

#####################REGISTER BLOCKING HISTOGRAM#######################
OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC8.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR8_BC8.png ${OUTDIR}/${GRAPHNAME}_block_BR8_BC8
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC4.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR8_BC4.png ${OUTDIR}/${GRAPHNAME}_block_BR8_BC4
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC2.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR8_BC2.png ${OUTDIR}/${GRAPHNAME}_block_BR8_BC2
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR8_BC1.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR8_BC1.png ${OUTDIR}/${GRAPHNAME}_block_BR8_BC1
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC8.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR4_BC8.png ${OUTDIR}/${GRAPHNAME}_block_BR4_BC8
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC4.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR4_BC4.png ${OUTDIR}/${GRAPHNAME}_block_BR4_BC4
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC2.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR4_BC2.png ${OUTDIR}/${GRAPHNAME}_block_BR4_BC2
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR4_BC1.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR4_BC1.png ${OUTDIR}/${GRAPHNAME}_block_BR4_BC1
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC8.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR2_BC8.png ${OUTDIR}/${GRAPHNAME}_block_BR2_BC8
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC4.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR2_BC4.png ${OUTDIR}/${GRAPHNAME}_block_BR2_BC4
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC2.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR2_BC2.png ${OUTDIR}/${GRAPHNAME}_block_BR2_BC2
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR2_BC1.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR2_BC1.png ${OUTDIR}/${GRAPHNAME}_block_BR2_BC1
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC8.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR1_BC8.png ${OUTDIR}/${GRAPHNAME}_block_BR1_BC8
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC4.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR1_BC4.png ${OUTDIR}/${GRAPHNAME}_block_BR1_BC4
fi

OUTFILE=${OUTDIR}/${GRAPHNAME}_block_BR1_BC2.png
if [ ! -f ${OUTFILE} ]
then
    ./make_histogram ${OUTDIR}/${GRAPHNAME}_block_BR1_BC2.png ${OUTDIR}/${GRAPHNAME}_block_BR1_BC2
fi
