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

  cusparseSpMatDescr_t matrixA = 0;
  cusparseDnMatDescr_t matrixB = 0;
  cusparseDnMatDescr_t matrixC = 0;

  int *d_col, *d_row;
  double *d_val;
  double *d_B, *d_C;
  double alpha, beta;

  checkCudaErrors( cudaMalloc((void**)&d_row, (nVtx+1)*sizeof(int)) );
  checkCudaErrors( cudaMalloc((void**)&d_col, xadj[nVtx]*sizeof(int)) );
  checkCudaErrors( cudaMalloc((void**)&d_val, xadj[nVtx]*sizeof(double)) );

  bool uvm = true;

  size_t dense_matrix_size = ((size_t)nVtx)* nbvector * sizeof(double);
  std::cerr<<"Allocating B and C: "<<dense_matrix_size<<" ( "<<dense_matrix_size/1024./1024./1024.<<" GB) each\n";
  
  if (!uvm) {
    checkCudaErrors( cudaMalloc((void**)&d_B, dense_matrix_size));
    checkCudaErrors( cudaMalloc((void**)&d_C, dense_matrix_size));
  }
  else {
    checkCudaErrors( cudaMallocManaged((void**)&d_B, dense_matrix_size ) );
    checkCudaErrors( cudaMallocManaged((void**)&d_C, dense_matrix_size ) );
  }
    cudaMemcpy(d_B, in, nVtx*nbvector*sizeof(double), cudaMemcpyHostToDevice);

  

  cudaMemcpy(d_row, xadj, (nVtx+1)*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_col, adj, xadj[nVtx]*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_val, val, xadj[nVtx]*sizeof(double), cudaMemcpyHostToDevice);

  alpha = 1.0;
  beta = 0.0;


  cusparseStatus = cusparseCreateCsr(&matrixA,
				     nVtx, nVtx, xadj[nVtx],
				     d_row, d_col, d_val,
				     CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I, CUSPARSE_INDEX_BASE_ZERO, //32bit index
				     CUDA_R_64F
				     );
  checkCusparseError(cusparseStatus);
  
  cusparseStatus = cusparseCreateDnMat(&matrixB,
				       nVtx, nbvector,
				       nbvector,
				       d_B, CUDA_R_64F,
				       CUSPARSE_ORDER_ROW);
  checkCusparseError(cusparseStatus);
  
  cusparseStatus = cusparseCreateDnMat(&matrixC,
				       nVtx, nbvector,
				       nbvector,
				       d_C, CUDA_R_64F,
				       CUSPARSE_ORDER_ROW);
  checkCusparseError(cusparseStatus);

  size_t bsize = -1;
  cusparseStatus = cusparseSpMM_bufferSize(cusparseHandle,
				CUSPARSE_OPERATION_NON_TRANSPOSE, CUSPARSE_OPERATION_NON_TRANSPOSE,
				&alpha,
				(cusparseConstSpMatDescr_t)matrixA, (cusparseConstDnMatDescr_t)matrixB,
				&beta,
				matrixC,
				CUDA_R_64F,
				CUSPARSE_SPMM_ALG_DEFAULT,
				&bsize);
  checkCusparseError(cusparseStatus);

  
  std::cerr<<"buffer size: "<<bsize<<" ( "<<bsize/1024./1024./1024. <<"GB)"<<"\n";
  char* buffer = NULL;
  checkCudaErrors( cudaMalloc((void**)&buffer, bsize) );

  
  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      cusparseStatus = cusparseSpMM(cusparseHandle,
				    CUSPARSE_OPERATION_NON_TRANSPOSE, CUSPARSE_OPERATION_NON_TRANSPOSE,
				    &alpha,
				    (cusparseConstSpMatDescr_t) matrixA, (cusparseConstDnMatDescr_t)matrixB,
				    &beta,
				    matrixC,
				    CUDA_R_64F,
				    CUSPARSE_SPMM_ALG_DEFAULT,
				    buffer);
      checkCusparseError(cusparseStatus);
    }
  checkCudaErrors( cudaDeviceSynchronize());
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



