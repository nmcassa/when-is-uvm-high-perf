CXXFLAGS=-std=c++17 -O3 -fopenmp -march=native -mtune=native
LDFLAGS=-fopenmp 

all: polynomial polynomial_openmp

polynomial: polynomial.cpp

polynomial_openmp: polynomial_openmp.cpp


clean:
	-rm polynomial polynomial_openmp

