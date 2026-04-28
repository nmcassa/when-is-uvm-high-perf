import sys

datasize=4

def inter_time(n,d,inter_bw):
    return 2*(n+d+1)*datasize/inter_bw

def gpu_mem_time(n, d, gpu_bw):
    return 2*(n+d+1)*datasize/gpu_bw

def gpu_comp_time(n,d,gpu_flops):
    return 2*n*(d+1)/gpu_flops

def overlapped_prediction(n, d, inter_bw, gpu_bw, gpu_flops):
    gpu_memtime=gpu_mem_time(n, d, gpu_bw)
    gpu_comptime=gpu_comp_time(n,d,gpu_flops)
    int_time=inter_time(n,d,inter_bw)

    overlapped_time = max(int_time,max(gpu_comptime, gpu_memtime))
    return overlapped_time

def nonoverlapped_prediction(n, d, inter_bw, gpu_bw, gpu_flops):
    gpu_memtime=gpu_mem_time(n, d, gpu_bw)
    gpu_comptime=gpu_comp_time(n,d,gpu_flops)
    int_time=inter_time(n,d,inter_bw)

    non_overlapped_time = int_time+max(gpu_comptime, gpu_memtime)
    return non_overlapped_time


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print ("n d interBW gpuBW gpuFlops")
        sys.exit(1)

    n=int(sys.argv[1])
    d=int(sys.argv[2])

    inter_bw=float(sys.argv[3])
    gpu_bw=float(sys.argv[4])
    gpu_flops=float(sys.argv[5])

    gpu_memtime=gpu_mem_time(n, d, gpu_bw)
    gpu_comptime=gpu_comp_time(n,d,gpu_flops)
    int_time=inter_time(n,d,inter_bw)

    non_overlapped_time = int_time+max(gpu_comptime, gpu_memtime)
    overlapped_time = max(int_time,max(gpu_comptime, gpu_memtime))

    print (f"gpu mem time: {gpu_memtime}")
    print (f"gpu comp time: {gpu_comptime}")
    print (f"interconnect time: {int_time}")
    print (f"no overlap: {non_overlapped_time}")
    print (f"overlapped time: {overlapped_time}")
