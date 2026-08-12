CUDA_ROOT ?= $(patsubst %/bin/nvcc,%,$(shell which nvcc))
CUPTI     := $(CUDA_ROOT)/extras/CUPTI
ARCH      := -gencode arch=compute_60,code=sm_60 -gencode arch=compute_80,code=sm_80
NVCC      := nvcc
FLAGS     := -O3 -std=c++14 $(ARCH) -Xcompiler -fopenmp

all: uvm_phase

uvm_phase: uvm_phase.cu
	$(NVCC) $(FLAGS) -DUSE_CUPTI $< -o $@ \
	  -I$(CUPTI)/include -L$(CUPTI)/lib64 -lcupti \
	  -Xlinker -rpath=$(CUPTI)/lib64

nocupti: uvm_phase.cu
	$(NVCC) $(FLAGS) $< -o uvm_phase_nocupti

clean:
	rm -f uvm_phase uvm_phase_nocupti
