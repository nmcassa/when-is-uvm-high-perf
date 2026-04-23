#!/bin/sh

grep filename\: experiment1-8.out > basic_spmm-8.out
grep filename\: experiment1-16.out > basic_spmm-16.out
grep filename\: experiment1-32.out > basic_spmm-32.out
grep filename\: experiment1-64.out > basic_spmm-64.out

gnuplot <<EOF
set terminal pdf;
set output 'basic_spmm.pdf';

set xlabel 'k';
set ylabel 'performance (in GFlops)';

set style data linespoints;

plot 'basic_spmm-8.out'  u 8:12 t 'd=8';
plot 'basic_spmm-16.out'  u 8:12  t 'd=16';
plot 'basic_spmm-32.out'  u 8:12  t 'd=32';
plot 'basic_spmm-64.out'  u 8:12 t 'd=64';
plot 'basic_spmm-8.out'  u 8:12 t 'd=8', 'basic_spmm-16.out'  u 8:12 t 'd=16', 'basic_spmm-32.out'  u 8:12 t 'd=32', 'basic_spmm-64.out'  u 8:12 t 'd=64';
EOF

