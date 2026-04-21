all: cuda-pr
	
cuda-pr:
	nvcc -g -G -O0 -Xcompiler -fopenmp -o cuda-pr graphIO.cpp cuda-pr.cu -lcublas -lcusparse

clean:
	rm cuda-pr
