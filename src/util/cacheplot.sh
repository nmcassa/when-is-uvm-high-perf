#!/bin/sh

CACHESIZES="32K 256K 512K 20M"
DATASIZES="4 8 16 32 64"
GRAPHS="amazon0601.txt loc-gowalla_edges_FIXED.txt web-Google.txt web-NotreDame.txt wiki-Talk.txt com-orkut.bin soc-LiveJournal1.txt"

logdir=analysis/

##getting logs in usable format
for graph in $GRAPHS;
do
    for cachesize in $CACHESIZES;
    do 
	hit_ratio_file=hit_ratio_${graph}_${cachesize}
	for datasize in $DATASIZES;
	do
	    logfile=${logdir}/${graph}_cache_${datasize}_64_${cachesize}

	    if [ -e ${logfile} ]
	    then
		echo $datasize `grep filename $logfile | cut -d \  -f 10`
	    fi
	done > $hit_ratio_file
    done
done

##plot hit ratio per graph

GNUPLOTCMD="set terminal postscript; set output 'hit_ratio_per_graph.ps';"
GNUPLOTCMD="${GNUPLOTCMD} set xlabel 'NB_BFS';"
GNUPLOTCMD="${GNUPLOTCMD} set ylabel 'cache hit ratio'; set yrange[0:1];"
GNUPLOTCMD="${GNUPLOTCMD} set style data linespoints;"
GNUPLOTCMD="${GNUPLOTCMD} set key bottom left;"

GNUPLOTPLOT=""
for graph in $GRAPHS;
do
    GNUPLOTPLOT="${GNUPLOTPLOT} set title '${graph}'; "
    GNUPLOTPLOT="${GNUPLOTPLOT} plot "
    for cachesize in $CACHESIZES;
    do 
	hit_ratio_file=hit_ratio_${graph}_${cachesize}

	GNUPLOTPLOT="${GNUPLOTPLOT} '${hit_ratio_file}' u (\$1*8):2 t '${cachesize}',"
    done
    GNUPLOTPLOT="${GNUPLOTPLOT} ;"
done

GNUPLOTPLOT=`echo $GNUPLOTPLOT | sed 's/, ;/;/g'`

echo $GNUPLOTCMD $GNUPLOTPLOT | gnuplot
ps2pdf hit_ratio_per_graph.ps

##plot hit ratio per cachesize
GNUPLOTCMD="set terminal postscript; set output 'hit_ratio_per_cachesize.ps';"
GNUPLOTCMD="${GNUPLOTCMD} set xlabel 'NB_BFS';"
GNUPLOTCMD="${GNUPLOTCMD} set ylabel 'cache hit ratio'; set yrange[0:1];"
GNUPLOTCMD="${GNUPLOTCMD} set style data linespoints;"
GNUPLOTCMD="${GNUPLOTCMD} set key bottom left;"

GNUPLOTPLOT=""
for cachesize in $CACHESIZES;
do
    GNUPLOTPLOT="${GNUPLOTPLOT} set title '${cachesize}'; "
    GNUPLOTPLOT="${GNUPLOTPLOT} plot "
    for graph in $GRAPHS;
    do 
	hit_ratio_file=hit_ratio_${graph}_${cachesize}

	GNUPLOTPLOT="${GNUPLOTPLOT} '${hit_ratio_file}' u (\$1*8):2 t '${graph}',"
    done
    GNUPLOTPLOT="${GNUPLOTPLOT} ;"
done

GNUPLOTPLOT=`echo $GNUPLOTPLOT | sed 's/, ;/;/g'`

echo $GNUPLOTCMD $GNUPLOTPLOT | gnuplot
ps2pdf hit_ratio_per_cachesize.ps
