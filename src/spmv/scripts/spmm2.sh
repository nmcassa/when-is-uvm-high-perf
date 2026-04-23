#!/bin/sh

files1="/scratch1/graphs/RandomDiag_33554430_*.graph"
files2="/scratch1/graphs/clippeddiagonal_*.graph"

REPEAT=4

for f1 in $files1;
do
    for f2 in $files2;
    do
	for k in 1 2 4 8 16 32 64 72 80 88 96 128 136 144 152 160 ;
	do
	    ../frankenstein $f1 $f2 $k $REPEAT
	done
    done
done 2>&1 | tee spmm2.out
