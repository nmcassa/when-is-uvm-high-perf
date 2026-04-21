// uvm_vs_explicit_subset.cu
#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <cassert>

#define CHECK_CUDA(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            printf("CUDA Error: %s\n", cudaGetErrorString(err)); \
            exit(1); \
        } \
    } while (0)

// -----------------------------
// Configurable parameters
// -----------------------------
size_t TABLE_SIZE = 1ULL << 28;       // ~1GB (ints)
int ACTIVE_SET_SIZE = 1 << 20;        // subset (1M entries)
size_t NUM_ACCESSES = 1 << 24;           // number of random accesses
const int THREADS = 256;
const int PAGE_SIZE = 4096 * 16;
size_t NUM_PAGES = 0;

// -----------------------------
// Kernel: random subset accesses
// -----------------------------
__global__ void probe_kernel(char* table,
                             size_t* active_pages,
                             int active_size,
                             size_t num_accesses,
                             unsigned long long* out)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    unsigned long long local = 0;

    if (idx >= num_accesses) return;

    size_t page = active_pages[idx % active_size];

    char* base = table + page * PAGE_SIZE;

    local += base[0];   // one touch per page

    atomicAdd(out, local);
}

// -----------------------------
// Initialize active subset
// -----------------------------
void init_active(size_t* active)
{
    for (size_t i = 0; i < ACTIVE_SET_SIZE; i++) {
        active[i] = rand() % NUM_PAGES;
    }
}

// -----------------------------
// Initialize table sparsely
// -----------------------------
void init_table(char* table, size_t* active)
{
    // only initialize subset (important for UVM laziness)
    for (size_t i = 0; i < ACTIVE_SET_SIZE; i++) {
	size_t page = active[i];
        table[page * PAGE_SIZE] = (char)i;
    }
}

// -----------------------------
// Timing helper
// -----------------------------
float run_kernel(char* d_table, size_t* d_active, unsigned long long* d_out)
{
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    int blocks = 1024;

    CHECK_CUDA(cudaMemset(d_out, 0, sizeof(unsigned long long)));

    cudaEventRecord(start);

    probe_kernel<<<blocks, THREADS>>>(d_table, d_active,
                                     ACTIVE_SET_SIZE,
                                     NUM_ACCESSES,
                                     d_out);

    CHECK_CUDA(cudaDeviceSynchronize());

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms;
    cudaEventElapsedTime(&ms, start, stop);

    return ms;
}

// -----------------------------
// MAIN
// -----------------------------
int main(int argc, char* argv[])
{
	if (argc < 4) {
		printf("Usage: %s <table_size_GB> <active_fraction> <access_multiplier>\n", argv[0]);
		printf("Example: %s 4 0.001 16\n", argv[0]);
		return 1;
	}

	double table_size_gb = atof(argv[1]);
	double active_fraction = atof(argv[2]);
	double access_multiplier = atof(argv[3]);

	// Compute sizes
	TABLE_SIZE = (table_size_gb * 1e9);
	NUM_PAGES = TABLE_SIZE / PAGE_SIZE;
	ACTIVE_SET_SIZE = (int)(NUM_PAGES * active_fraction);
	NUM_ACCESSES = (size_t)(50 * ACTIVE_SET_SIZE);

	// sanity checks
	if (ACTIVE_SET_SIZE <= 0 || NUM_ACCESSES <= 0) {
		printf("Invalid configuration.\n");
		return 1;
	}

	printf("TABLE_SIZE: %zu (%.2f GB)\n", TABLE_SIZE,
		TABLE_SIZE * sizeof(int) / 1e9);
	printf("ACTIVE_SET_SIZE: %d (%.6f%%)\n",
		ACTIVE_SET_SIZE,
		100.0 * active_fraction);
	printf("NUM_ACCESSES: %zu\n", NUM_ACCESSES);

	// host allocations
	size_t* h_active = (size_t*)malloc(ACTIVE_SET_SIZE * sizeof(size_t));
	init_active(h_active);

	// -----------------------------
	// UVM VERSION
	// -----------------------------
	char* uvm_table;
	size_t* uvm_active;
	unsigned long long* uvm_out;


	CHECK_CUDA(cudaMallocManaged(&uvm_table, TABLE_SIZE * sizeof(size_t)));
	CHECK_CUDA(cudaMallocManaged(&uvm_active, ACTIVE_SET_SIZE * sizeof(size_t)));
	CHECK_CUDA(cudaMallocManaged(&uvm_out, sizeof(unsigned long long)));

	memcpy(uvm_active, h_active, ACTIVE_SET_SIZE * sizeof(int));

	CHECK_CUDA(cudaMemPrefetchAsync(uvm_table, TABLE_SIZE, cudaCpuDeviceId));
	CHECK_CUDA(cudaDeviceSynchronize());

	// IMPORTANT: only initialize subset
	init_table(uvm_table, uvm_active);

	CHECK_CUDA(cudaDeviceSynchronize());

	float uvm_time = run_kernel(uvm_table, uvm_active, uvm_out);

	printf("UVM time: %.3f ms\n", uvm_time);

	CHECK_CUDA(cudaFree(uvm_table));
	CHECK_CUDA(cudaFree(uvm_active));
	CHECK_CUDA(cudaFree(uvm_out));

	// -----------------------------
	// EXPLICIT VERSION (FIXED)
	// -----------------------------
	char* h_table = (char*)malloc(TABLE_SIZE * sizeof(char));
	memset(h_table, 0, TABLE_SIZE * sizeof(char));

	init_table(h_table, h_active);

	char* d_table;
	size_t* d_active;
	unsigned long long* d_out;

	CHECK_CUDA(cudaMalloc(&d_table, TABLE_SIZE * sizeof(char)));
	CHECK_CUDA(cudaMalloc(&d_active, ACTIVE_SET_SIZE * sizeof(size_t)));
	CHECK_CUDA(cudaMalloc(&d_out, sizeof(unsigned long long)));

	// --- Timing events ---
	cudaEvent_t start_total, stop_total;
	cudaEvent_t start_copy, stop_copy;
	cudaEventCreate(&start_total);
	cudaEventCreate(&stop_total);
	cudaEventCreate(&start_copy);
	cudaEventCreate(&stop_copy);

	cudaEventRecord(start_total);

	cudaEventRecord(start_copy);

	// NOTE: full table copy (this is the key cost!)
	CHECK_CUDA(cudaMemcpy(d_table, h_table,
			      TABLE_SIZE * sizeof(char),
			      cudaMemcpyHostToDevice));

	CHECK_CUDA(cudaMemcpy(d_active, h_active,
			      ACTIVE_SET_SIZE * sizeof(char),
			      cudaMemcpyHostToDevice));

	cudaEventRecord(stop_copy);
	cudaEventSynchronize(stop_copy);

	float kernel_time = run_kernel(d_table, d_active, d_out);

	cudaEventRecord(stop_total);
	cudaEventSynchronize(stop_total);

	float copy_ms, total_ms;
	cudaEventElapsedTime(&copy_ms, start_copy, stop_copy);
	cudaEventElapsedTime(&total_ms, start_total, stop_total);

	printf("Explicit: %.3f ms\n", total_ms);

return 0;
}
