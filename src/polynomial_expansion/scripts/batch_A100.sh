#!/bin/bash
#SBATCH --partition=GPU
#SBATCH --nodes=1
#SBATCH --time=36:00:00
#
#SBATCH --ntasks-per-node=32
#SBATCH --gres=gpu:A100:1
#SBATCH --mem=220G
#SBATCH --nodelist=str-gpu13

cd ~/polynomial_expansion/scripts/

./bench.sh

