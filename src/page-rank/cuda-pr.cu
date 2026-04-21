#include "main-pr.hpp"

#define THROW_AWAY 0
#include <omp.h>
#include <cmath>
#include <vector>

//#define SHOWLOADBALANCE

//#define LOG

#include <cuda_runtime_api.h>
#include <cuda_runtime.h>
#include <cusparse_v2.h>
#include <cublas_v2.h>
#include "helper_cuda.h"

__global__ void count_active_edges(
    int* active,
    int nActive,
    uint64_t* xadj,
    unsigned long long* edge_count)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= nActive) return;

    int v = active[i];
    unsigned long long deg = xadj[v+1] - xadj[v];

    atomicAdd(edge_count, deg);
}

__global__ void bfs_expand(
    int* frontier,
    int* frontier_size,
    int* next_frontier,
    int* next_size,
    int* visited,
    uint64_t* xadj,
    uint32_t* adj)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    int size = *frontier_size;

    if (i >= size) return;

    int v = frontier[i];

    int start = xadj[v];
    int end = xadj[v+1];

    for (int e = start; e < end; e++) {
        int u = adj[e];

        if (visited[u] == 0 && atomicExch(&visited[u], 1) == 0) {
            int pos = atomicAdd(next_size, 1);
            next_frontier[pos] = u;
        }
    }
}

__global__ void build_active(
    int* visited,
    int n,
    int* active,
    int* active_size)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;

    if (visited[i]) {
        int pos = atomicAdd(active_size, 1);
        active[pos] = i;
    }
}

__global__ void compute_active_residual(
    int* active,
    int nActive,
    float* prin,
    float* prout,
    float* eps)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= nActive) return;

    int v = active[i];

    float diff = fabsf(prin[v] - prout[v]);

    atomicAdd(eps, diff);
}

__global__ void pr_kernel(
    int* active,
    int nActive,
    uint64_t* xadj,
    uint32_t* adj,
    float* val,
    float* prin,
    float* prout)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= nActive) return;
    
    int v = active[i];

    float sum = 0;

    int start = xadj[v];
    int end = xadj[v+1];

    for (int e = start; e < end; e++) {
        int u = adj[e];
        sum += val[e] * prin[u];
    }

    prout[v] = sum;
}

template <typename VertexType, typename EdgeType, typename Scalar>
int main_pr(VertexType nVtx, EdgeType* xadj_, VertexType *adj_, Scalar* val_, Scalar *prior_, Scalar* pr_,
	    Scalar lambda,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string&, int BFS_DEPTH, int use_uvm
	      )
{
  bool coldcache = true;
  
  util::timestamp start(0,0);
  util::timestamp stop;  

  //cpuside variables  
  Scalar* prin_ = new Scalar[nVtx];
  EdgeType* xadj = xadj_;
  VertexType *adj = adj_;
  Scalar* val = val_;
  Scalar* prior = prior_;
  Scalar* prin = prin_;
  Scalar* prout = pr_;
  Scalar alpha = lambda;
  Scalar beta = 1-lambda;

  //cuda side variable
  EdgeType* d_xadj ;
  VertexType *d_adj ;
  Scalar* d_val ;
  Scalar* d_prior ;
  Scalar* d_prin ;
  Scalar* d_prout ;
  Scalar *d_alpha;
  Scalar *d_beta;

  /* Get handle to the CUBLAS context */
  cublasHandle_t cublasHandle = 0;
  cublasStatus_t cublasStatus;
  cublasStatus = cublasCreate(&cublasHandle);

  int *d_frontier;
  int *d_next_frontier;
  int *d_frontier_size;
  int *d_next_size;
  int *d_visited;

  int* d_active;
  int* d_active_size;

  float* d_eps;

  //memalloc
  if (use_uvm) {
    cudaMallocManaged(&d_xadj, (nVtx+1)*sizeof(*xadj));
    cudaMallocManaged(&d_adj, xadj[nVtx]*sizeof(*adj));
    cudaMallocManaged(&d_val, xadj[nVtx]*sizeof(*val));
    cudaMallocManaged(&d_prior, nVtx*sizeof(*prior));
    cudaMallocManaged(&d_prin, nVtx*sizeof(*prin));
    cudaMallocManaged(&d_prout, nVtx*sizeof(*prout));

    cudaMallocManaged(&d_frontier, nVtx*sizeof(int));
    cudaMallocManaged(&d_next_frontier, nVtx*sizeof(int));
    cudaMallocManaged(&d_frontier_size, sizeof(int));
    cudaMallocManaged(&d_next_size, sizeof(int));
    cudaMallocManaged(&d_visited, nVtx*sizeof(int));

    cudaMallocManaged(&d_active, nVtx * sizeof(int));
    cudaMallocManaged(&d_active_size, sizeof(int));
    cudaMallocManaged(&d_eps, sizeof(float));
  } else {
    cudaMalloc(&d_xadj, (nVtx+1)*sizeof(*xadj));
    cudaMalloc(&d_adj, xadj[nVtx]*sizeof(*adj));
    cudaMalloc(&d_val, xadj[nVtx]*sizeof(*val));
    cudaMalloc(&d_prior, nVtx*sizeof(*prior));
    cudaMalloc(&d_prin, nVtx*sizeof(*prin));
    cudaMalloc(&d_prout, nVtx*sizeof(*prout));

    cudaMalloc(&d_frontier, nVtx*sizeof(int));
    cudaMalloc(&d_next_frontier, nVtx*sizeof(int));
    cudaMalloc(&d_frontier_size, sizeof(int));
    cudaMalloc(&d_next_size, sizeof(int));
    cudaMalloc(&d_visited, nVtx*sizeof(int));

    cudaMalloc(&d_active, nVtx * sizeof(int));
    cudaMalloc(&d_active_size, sizeof(int));
    cudaMalloc(&d_eps, sizeof(float));
  }



  //cpu to gpu copies
  int zero = 0;
  if (!use_uvm) {
  	  start = util::timestamp();
	  checkCudaErrors( cudaMemcpy(d_xadj, xadj, (nVtx+1)*sizeof(*xadj), cudaMemcpyHostToDevice) );
	  checkCudaErrors( cudaMemcpy(d_adj, adj, (xadj[nVtx])*sizeof(*adj), cudaMemcpyHostToDevice) );
	  checkCudaErrors( cudaMemcpy(d_val, val, (xadj[nVtx])*sizeof(*val), cudaMemcpyHostToDevice) );
	  checkCudaErrors( cudaMemcpy(d_prior, prior, nVtx*sizeof(*prior), cudaMemcpyHostToDevice) );
	  checkCudaErrors( cudaMemcpy(d_active_size, &zero, sizeof(int), cudaMemcpyHostToDevice) );
	  stop = util::timestamp();
	  totaltime = stop - start;
  } else {
	  memcpy(d_xadj, xadj, (nVtx+1)*sizeof(*xadj));
	  memcpy(d_adj, adj, (xadj[nVtx])*sizeof(*adj));
	  memcpy(d_val, val, (xadj[nVtx])*sizeof(*val));
	  memcpy(d_prior, prior, nVtx*sizeof(*prior));
	  *d_active_size = 0;
  }

  std::vector<int> h_visited(nVtx, 0);
  std::vector<int> h_frontier(nVtx);

  int h_frontier_size = 5;
  int h_queries[] = {10, nVtx / 2, nVtx -10, nVtx / 4, 3 * nVtx / 4};

  for (int i = 0; i < h_frontier_size; i++) {
    h_frontier[i] = h_queries[i];
    h_visited[h_queries[i]] = 1;
  }

  if (use_uvm) {
    memcpy(d_visited, h_visited.data(), nVtx * sizeof(int));
    memcpy(d_frontier, h_frontier.data(), nVtx * sizeof(int));
    *d_frontier_size = h_frontier_size;
  } else {
    start = util::timestamp();
    cudaMemcpy(d_visited, h_visited.data(), nVtx * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_frontier, h_frontier.data(), nVtx * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_frontier_size, &h_frontier_size, sizeof(int), cudaMemcpyHostToDevice);
    stop = util::timestamp();
    totaltime += stop - start;
  }
    
  int max_blocks = (nVtx + 31) / 32;
  //printf("%d\n", max_blocks * 32);

  start = util::timestamp();

  // BFS 
  for (int depth = 0; depth < BFS_DEPTH; depth++) {	
    cudaMemset(d_next_size, 0, sizeof(int));

    bfs_expand<<<(h_frontier_size + 31) / 32, 32>>>(
        d_frontier,
        d_frontier_size,
        d_next_frontier,
        d_next_size,
        d_visited,
        d_xadj,
        d_adj
    );

    cudaDeviceSynchronize();

    // swap frontiers
    std::swap(d_frontier, d_next_frontier);

    cudaMemcpy(d_frontier_size, d_next_size, sizeof(int), cudaMemcpyDeviceToDevice);
    cudaMemcpy(&h_frontier_size, d_frontier_size, sizeof(int), cudaMemcpyDeviceToHost);
  }
  stop = util::timestamp();

  cudaMemset(d_active_size, 0, sizeof(int));

  build_active<<<(h_frontier_size + 31) / 32, 32>>>(
    d_visited,
    nVtx,
    d_active,
    d_active_size
  );

  cudaDeviceSynchronize();

  int h_active_size;
 
  if (use_uvm) {
    h_active_size = *d_active_size;
  } else {
    cudaMemcpy(&h_active_size, d_active_size, sizeof(int), cudaMemcpyDeviceToHost);
  }

  unsigned long long* d_active_edges;
unsigned long long h_active_edges = 0;

if (use_uvm) {
    cudaMallocManaged(&d_active_edges, sizeof(unsigned long long));
} else {
    cudaMalloc(&d_active_edges, sizeof(unsigned long long));
}

cudaMemset(d_active_edges, 0, sizeof(unsigned long long));

count_active_edges<<<(h_active_size + 31)/32, 32>>>(
    d_active,
    h_active_size,
    d_xadj,
    d_active_edges
);

cudaDeviceSynchronize();

if (use_uvm) {
    h_active_edges = *d_active_edges;
} else {
    cudaMemcpy(&h_active_edges, d_active_edges,
               sizeof(unsigned long long),
               cudaMemcpyDeviceToHost);
}

  totaltime += stop - start;

  start = util::timestamp();


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY >= THROW_AWAY)
   		//start = util::timestamp();

      for (int iter = 0; iter < 20; ++ iter) {
	if (iter == 0)
	  checkCudaErrors(cudaMemcpy(d_prin, d_prior, nVtx*sizeof(*prior), cudaMemcpyDeviceToDevice));
	else
	  checkCudaErrors(cudaMemcpy(d_prin, d_prout, nVtx*sizeof(*prout), cudaMemcpyDeviceToDevice));
	
	checkCudaErrors(cudaMemcpy(d_prout, d_prior, nVtx*sizeof(*prior), cudaMemcpyDeviceToDevice));

	float eps = 0.0f;

	pr_kernel<<<(h_active_size+31)/32, 32>>>(
		d_active,
		h_active_size,
		d_xadj,
		d_adj,
		d_val,
		d_prin,
		d_prout
        );
	//getchar();

        //checkCudaErrors(cudaDeviceSynchronize());
	
	// reset eps
	cudaMemset(d_eps, 0, sizeof(float));

	// compute residual only on active set
	compute_active_residual<<<(h_active_size+31)/32, 32>>>(
	    d_active,
	    h_active_size,
	    d_prin,
	    d_prout,
	    d_eps
	);

	cudaDeviceSynchronize();

	/*
	if (iter % 5 == 0) {
		cudaMemcpy(&eps, d_eps, sizeof(float), cudaMemcpyDeviceToHost);
		
		//stopping condition
		if (!use_uvm) {
			std::cerr<<eps<<std::endl;
			if (eps < 0) // deactivited for testing purposes
			  iter = 20;
		} else {
			std::cerr<<eps<<std::endl;
			if (eps < 0) 
				iter = 20;
		}
	}
      */
	
      }
      
      stop = util::timestamp();
	
      if (!use_uvm)  {
      	checkCudaErrors(cudaMemcpy(prout, d_prout, nVtx*sizeof(*prout), cudaMemcpyDeviceToHost));
      } else {
           for (int i = 0; i < *d_active_size; i++) {
	       int v = d_active[i];
               prout[v] = d_prout[v];  // triggers page fault ONLY for touched pages
	   }
      }

      std::cerr<<"PR[0]="<<prout[0]<<"\n"<<std::endl;

      if (TRY >= THROW_AWAY)
	{
	  //util::timestamp stop;  
	  //totaltime += stop - start;
	}
      
#ifndef LOG
      if (coldcache) {
#pragma omp parallel
	{
		/*
	  evict_array_from_cache(adj, xadj[nVtx]*sizeof(*adj));
	  evict_array_from_cache(xadj, (nVtx+1)*sizeof(*xadj));
	  evict_array_from_cache(val, xadj[nVtx]*sizeof(*val));
	  evict_array_from_cache(prior, nVtx*sizeof(*prior));
	  evict_array_from_cache(prin, nVtx*sizeof(*prin));
	  evict_array_from_cache(prout, nVtx*sizeof(*prout));
	  */

#pragma omp barrier
	}
      }
#endif

    }

      //util::timestamp stop;  
      totaltime += stop - start;
      double edges_per_sec = (double)h_active_edges / totaltime;
      printf("Nodes-per-sec: %f\n", edges_per_sec); 

#ifdef SHOWLOADBALANCE
  std::cout<<"load balance"<<std::endl;
  for (int i=0; i< 244; ++i)
    std::cout<<count[i]<<std::endl;
#endif

  delete[] prin_;

  return 0;
}

  
  
