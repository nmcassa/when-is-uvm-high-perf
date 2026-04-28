CXXFLAGS=-std=c++17 -O3 -fopenmp -march=native -mtune=native
LDFLAGS=-fopenmp 
CUDAFLAGS=-O3 -std=c++17 -arch=sm_80

BINS=polynomial_gpu_pinned polynomial_gpu_basic polynomial_gpu_stream polynomial_gpu_hmm_basic polynomial_gpu_uvm_basic polynomial_gpu_excluding_transfer

all: $(BINS)

polynomial_gpu_basic: polynomial_gpu_basic.cu
	nvcc $(CUDAFLAGS) $< -o $@

polynomial_gpu_excluding_transfer: polynomial_gpu_excluding_transfer.cu
	nvcc $(CUDAFLAGS) $< -o $@

polynomial_gpu_pinned: polynomial_gpu_pinned.cu
	nvcc $(CUDAFLAGS) $< -o $@


polynomial_gpu_stream: polynomial_gpu_stream.cu
	nvcc $(CUDAFLAGS) $< -o $@


polynomial_gpu_uvm_basic: polynomial_gpu_uvm_basic.cu
	nvcc $(CUDAFLAGS) $< -o $@

polynomial_gpu_hmm_basic: polynomial_gpu_hmm_basic.cu
	nvcc $(CUDAFLAGS) $< -o $@


clean:
	-rm $(BINS)


