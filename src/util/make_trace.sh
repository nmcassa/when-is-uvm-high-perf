#!/bin/sh

cd $HOME/ShMemColoring/src/util

#GRAPHPATH=$1
GRAPHNAME=`basename $GRAPHPATH`
OUTDIR=analysis/

mkdir -p $OUTDIR


#####################TRACE#######################

OUTFILE=${OUTDIR}/${GRAPHNAME}_plot_2048.png
if [ ! -f ${OUTFILE} ]
then
    ./plot ${GRAPHPATH} ${GRAPHNAME} 2048
    convert ${GRAPHNAME}.pgm ${OUTFILE}
    rm ${GRAPHNAME}.pgm
fi
