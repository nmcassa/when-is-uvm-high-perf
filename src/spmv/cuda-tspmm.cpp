#include "main-spmm.hpp"
#include <immintrin.h>

#define THROW_AWAY 10

#include <cuda_runtime_api.h>
#include <cusparse_v2.h>
#include <cublas_v2.h>
#include "helper_cuda.h"


template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmm(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out, int nbvector,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  /* Get handle to the CUBLAS context */
  cublasHandle_t cublasHandle = 0;
  cublasStatus_t cublasStatus;
  cublasStatus = cublasCreate(&cublasHandle);

  /* Get handle to the CUSPARSE context */
  cusparseHandle_t cusparseHandle = 0;
  cusparseStatus_t cusparseStatus;
  cusparseStatus = cusparseCreate(&cusparseHandle);

  cusparseMatDescr_t descr = 0;
  cusparseStatus = cusparseCreateMatDescr(&descr);

  cusparseSetMatType(descr,CUSPARSE_MATRIX_TYPE_GENERAL);
  cusparseSetMatIndexBase(descr,CUSPARSE_INDEX_BASE_ZERO);

  int *d_col, *d_row;
  double *d_val;
  double *d_B, *d_C;
  double alpha, beta;

  checkCudaErrors( cudaMalloc((void**)&d_row, (nVtx+1)*sizeof(int)) );
  checkCudaErrors( cudaMalloc((void**)&d_col, xadj[nVtx]*sizeof(int)) );
  checkCudaErrors( cudaMalloc((void**)&d_val, xadj[nVtx]*sizeof(double)) );

  checkCudaErrors( cudaMalloc((void**)&d_B, nVtx* nbvector * sizeof(double)) );
  cudaMemcpy(d_B, in, nVtx*nbvector*sizeof(double), cudaMemcpyHostToDevice);
  checkCudaErrors( cudaMalloc((void**)&d_C, nVtx * nbvector * sizeof(double)) );


  cudaMemcpy(d_row, xadj, (nVtx+1)*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_col, adj, xadj[nVtx]*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_val, val, xadj[nVtx]*sizeof(double), cudaMemcpyHostToDevice);

  alpha = 1.0;
  beta = 0.0;



  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      cusparseDcsrmm(cusparseHandle, CUSPARSE_OPERATION_TRANSPOSE, nVtx, nbvector, nVtx, xadj[nVtx], &alpha, descr, d_val, d_row, d_col, d_B, nVtx, &beta, d_C, nVtx);
      cudaThreadSynchronize();


    }
  util::timestamp stop;  

  totaltime += stop - start;


  cudaFree(d_B);
  cudaFree(d_C);
  cusparseDestroy(cusparseHandle);
  cublasDestroy(cublasHandle);
  cudaFree(d_row);
  cudaFree(d_col);
  cudaFree(d_val);

  cudaDeviceReset();

  return 0;
}



