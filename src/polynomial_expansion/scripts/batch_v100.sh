#!/bin/bash
#SBATCH --partition=GPU
#SBATCH --nodes=1
#SBATCH --time=36:00:00
#
#SBATCH --ntasks-per-node=16
#SBATCH --gres=gpu:V100:1
#SBATCH --mem=160G
#SBATCH --nodelist=str-gpu4

cd ~/polynomial_expansion/scripts/

./bench.sh

