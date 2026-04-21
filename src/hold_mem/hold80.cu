#include <cuda_runtime.h>
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    size_t gb = 80;
    size_t bytes = gb * (1ULL << 30);  // 80 * 2^30 bytes

    std::cout << "Attempting to allocate " << gb << " GB on GPU..." << std::endl;

    void* d_ptr = nullptr;

    cudaError_t err = cudaMalloc(&d_ptr, bytes);

    if (err != cudaSuccess) {
        std::cerr << "cudaMalloc failed: "
                  << cudaGetErrorString(err) << std::endl;
        return 1;
    }

    std::cout << "Allocation successful at " << d_ptr << std::endl;
    std::cout << "Holding allocation... press Ctrl+C to exit." << std::endl;

    // Touch memory lightly to ensure it is actually backed (optional but useful)
    cudaMemset(d_ptr, 0, bytes);

    // Stall forever so memory stays allocated
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(10));
    }

    // unreachable, but clean-up if needed
    cudaFree(d_ptr);
    return 0;
}
