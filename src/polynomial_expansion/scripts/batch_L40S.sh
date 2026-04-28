#!/bin/bash
#SBATCH --partition=GPU
#SBATCH --nodes=1
#SBATCH --time=36:00:00
#
#SBATCH --ntasks-per-node=64
#SBATCH --gres=gpu:L40S:1
#SBATCH --mem=500G
#SBATCH --nodelist=str-gpu24

cd ~/polynomial_expansion/scripts/

./bench.sh

