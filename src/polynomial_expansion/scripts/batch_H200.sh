#!/bin/bash
#SBATCH --partition=GPU
#SBATCH --nodes=1
#SBATCH --time=36:00:00
#
#SBATCH --ntasks-per-node=128
#SBATCH --gres=gpu:H200:1
#SBATCH --mem=700G
#SBATCH --nodelist=str-gpu30

cd ~/polynomial_expansion/scripts/

./bench.sh

