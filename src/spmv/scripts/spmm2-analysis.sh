#!/bin/sh

#grep filename spmm2.out

files1="/scratch1/graphs/RandomDiag_33554430_*.graph"
#files2="/scratch1/graphs/clippeddiagonal_*.graph"
files2="/scratch1/graphs/clippeddiagonal_33554432_888608.graph /scratch1/graphs/clippeddiagonal_33554432_1777216.graph /scratch1/graphs/clippeddiagonal_33554432_3554432.graph /scratch1/graphs/clippeddiagonal_33554432_7108864.graph"

REPEAT=4

PREFIX="spmm2-analysis"

for f1 in $files1;
do
    echo $f1
    f1base=$(basename $f1 .graph)
    grep -F $f1base spmm2.out > ${PREFIX}-${f1base}
    degree=$(echo $f1base | cut -d _ -f 3)
    PLOT=""
    for f2 in $files2;
    do
	echo $f1 $f2
	f2base=$(basename $f2 .graph)
	grep -F $f2base ${PREFIX}-${f1base} > ${PREFIX}-${f1base}-${f2base}

	overflow=$(echo $f2base | cut -d _ --output-delimiter=\  -f 2,3 | awk '{printf "%.3f\n", $2/$1;}')

	PLOT="${PLOT}, '${PREFIX}-${f1base}-${f2base}' u 10:14 t 'i/n=${overflow}'"
	gnuplot <<EOF
      	set terminal pdf;
	set output '${PREFIX}-${f1base}-${f2base}.pdf';
	set style data linespoints;
	set xlabel 'k';
	set ylabel 'Performance (GFlops)';
	set title 'd=${degree}' ;
	plot '${PREFIX}-${f1base}-${f2base}' u 10:14 t 'i/n=${overflow}';
EOF
    done
    PLOT=$(echo $PLOT | cut -d , -f 2-)
    gnuplot <<EOF
    set terminal pdf;
    set output '${PREFIX}-${f1base}.pdf';
    set style data linespoints;
    set xlabel 'k';
    set ylabel 'Performance (GFlops)';
    set key bottom center;
    set title 'd=${degree}' ;
    plot ${PLOT}
EOF
    
done

