#!/bin/sh

MATRICES="2cubes_sphere.mtx.bin atmosmodd.mtx.bin auto.mtx.bin bcsstm38.mtx.bin bmw3_2.mtx.bin cage14.mtx.bin cant.mtx.bin cop20k_A.mtx.bin crankseg_2.mtx.bin F1.mtx.bin hood.mtx.bin inline_1.mtx.bin ldoor.mtx.bin mac_econ_fwd500.mtx.bin mesh_2048_2048.mtx.bin msdoor.mtx.bin nd24k.mtx.bin pdb1HYS.mtx.bin pre2.mtx.bin pwtk.mtx.bin scircuit.mtx.bin shallow_water1.mtx.bin torso1.mtx.bin webbase-1M.mtx.bin"

ANALYSISDIR=analysis/

nrow ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 1 $FILE
}

ncol ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 2 $FILE
}

nnz ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 3 $FILE
}

density ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 4 $FILE
}

avgrowdegree ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 5 $FILE
}

avgcoldegree ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 6 $FILE
}

maxrowdegree ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 7 $FILE
}

maxcoldegree ()
{
    matrix=$1
    FILE=${ANALYSISDIR}/${matrix}_properties
    cut -d \   -f 7 $FILE
}

cachefriendliness ()
{
    matrix=$1
    datasize=$2
    cacheline=$3
    cachesize=$4
    FILE=${ANALYSISDIR}/${matrix}_cache_${datasize}_${cacheline}_${cachesize}
    cut -d \  -f 10 $FILE
}

normblockdensity ()
{
    matrix=$1
    BR=$2
    BC=$3
    FILE=${ANALYSISDIR}/${matrix}_block_BR${BR}_BC${BC}
    grep \#  < $FILE |cut -d \  -f 7
}

trim ()
{
    sed 's/\s\s*/ /g'
}

strongover ()
{
    val=`echo $1 | trim`
    thr=$2
    
    awk "END{if ( $val > $thr ){print \"<strong>$val</strong>\"}else{print $val;}}" </dev/null
}

echo "<html>"

echo "<style type=\"text/css\">"
echo ".odd{background-color: LightGray;}"
echo ".even{background-color: white;}"
echo "</style>"

echo "<body>"

echo "<table>"

echo "<tr>"

echo "<td>name</td>"
echo "<td>nrow</td>"
echo "<td>ncol</td>"
echo "<td>nnz</td>"
echo "<td>density</td>"
echo "<td>avgrowdegree</td>"
echo "<td>avgcoldegree</td>"
echo "<td>maxrowdegree</td>"
echo "<td>maxcoldegree</td>"


echo "<td>cachehit 16K</td>"
echo "<td>cachehit 32K</td>"
echo "<td>cachehit 128K</td>"
echo "<td>cachehit 256K</td>"
echo "<td>cachehit 512K</td>"

echo "<td>Block 8x8</td>"
echo "<td>Block 8x4</td>"
echo "<td>Block 8x2</td>"
echo "<td>Block 8x1</td>"

echo "<td>Block 4x8</td>"
echo "<td>Block 4x4</td>"
echo "<td>Block 4x2</td>"
echo "<td>Block 4x1</td>"

echo "<td>Block 2x8</td>"
echo "<td>Block 2x4</td>"
echo "<td>Block 2x2</td>"
echo "<td>Block 2x1</td>"

echo "<td>Block 1x8</td>"
echo "<td>Block 1x4</td>"
echo "<td>Block 1x2</td>"

echo "</tr>"


ALT="0"

for mat in $MATRICES
do
    if [ "$ALT" = "0" ]
    then
	echo "<tr class='odd'>"
	ALT="1"
    else
	echo "<tr class='even'>"
	ALT="0"
    fi

    echo "<td><a href=\"${mat}_plot_2048.png\">${mat}</a></td>"
    echo "<td>`nrow $mat`</td>"
    echo "<td>`ncol $mat`</td>"
    echo "<td>`nnz $mat`</td>"
    echo "<td>`density $mat`</td>"
    echo "<td><a href=\"${mat}_degree.png\">`avgrowdegree $mat`</a></td>"
    echo "<td><a href=\"${mat}_degree.png\">`avgcoldegree $mat`</a></td>"
    echo "<td><a href=\"${mat}_degree.png\">`maxrowdegree $mat`</a></td>"
    echo "<td><a href=\"${mat}_degree.png\">`maxcoldegree $mat`</a></td>"

    echo "<td>`cachefriendliness $mat 8 64 16K`</td>"
    echo "<td>`cachefriendliness $mat 8 64 32K`</td>"
    echo "<td>`cachefriendliness $mat 8 64 128K`</td>"
    echo "<td>`cachefriendliness $mat 8 64 256K`</td>"
    echo "<td>`cachefriendliness $mat 8 64 512K`</td>"

    echo "<td><a href=\"${mat}_block_BR8_BC8.png\">";DENS=`normblockdensity $mat 8 8`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR8_BC4.png\">";DENS=`normblockdensity $mat 8 4`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR8_BC2.png\">";DENS=`normblockdensity $mat 8 2`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR8_BC1.png\">";DENS=`normblockdensity $mat 8 1`; strongover $DENS 0.5 ; echo "</a></td>"

    echo "<td><a href=\"${mat}_block_BR4_BC8.png\">";DENS=`normblockdensity $mat 4 8`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR4_BC4.png\">";DENS=`normblockdensity $mat 4 4`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR4_BC2.png\">";DENS=`normblockdensity $mat 4 2`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR4_BC1.png\">";DENS=`normblockdensity $mat 4 1`; strongover $DENS 0.5 ; echo "</a></td>"

    echo "<td><a href=\"${mat}_block_BR2_BC8.png\">";DENS=`normblockdensity $mat 2 8`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR2_BC4.png\">";DENS=`normblockdensity $mat 2 4`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR2_BC2.png\">";DENS=`normblockdensity $mat 2 2`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR2_BC1.png\">";DENS=`normblockdensity $mat 2 1`; strongover $DENS 0.5 ; echo "</a></td>"

    echo "<td><a href=\"${mat}_block_BR1_BC8.png\">";DENS=`normblockdensity $mat 1 8`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR1_BC4.png\">";DENS=`normblockdensity $mat 1 4`; strongover $DENS 0.5 ; echo "</a></td>"
    echo "<td><a href=\"${mat}_block_BR1_BC2.png\">";DENS=`normblockdensity $mat 1 2`; strongover $DENS 0.5 ; echo "</a></td>"

    echo "</tr>"
done

echo "</table>"

echo "</body>"
echo "</html>"