#!/bin/sh

cd $HOME/ShMemColoring/src/util

#GRAPHPATH=$1
GRAPHNAME=`basename $GRAPHPATH`
OUTDIR=analysis/

if [ "$datasize" = "" ]
then
    echo specify datasize;
    exit
fi

if [ "$CACHELINE" = "" ]
then
    echo specify CACHELINE;
    exit
fi

if [ "$CACHESIZE" = "" ]
then
    echo specify CACHESIZE;
    exit
fi

mkdir -p $OUTDIR

case $CACHESIZE in
    20M)
	export cache_capacity=20971520
	;;
    512K)
	export cache_capacity=524288
	;;
    256K)
	export cache_capacity=262144
	;;
    32K)
	export cache_capacity=32768
	;;
    *)
	echo unsupported CACHESIZE
	exit
	;;
esac

#####################CACHE FRIENDLINESS#######################


OUTFILE=${OUTDIR}/${GRAPHNAME}_cache_${datasize}_${CACHELINE}_${CACHESIZE}
if [ ! -f ${OUTFILE} ]
then
    ./cache-friendliness $GRAPHPATH > ${OUTFILE}
fi


