#!/bin/sh

cd $HOME/ShMemColoring/src/util

#GRAPHPATH=$1
GRAPHNAME=`basename $GRAPHPATH`
OUTDIR=analysis/

mkdir -p $OUTDIR


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

