all: main

ARCH := -arch=sm_90

main: main.cu
	nvcc main.cu -O3 $(ARCH) -o main
