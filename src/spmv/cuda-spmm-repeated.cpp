#include "main-spmm.hpp"
#include <immintrin.h>

#define THROW_AWAY 0

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

  VertexType *d_col;
  EdgeType *d_row;
  double *d_val;
  double *d_B, *d_C;
  double alpha, beta;

  size_t Asize = (nVtx+1)*sizeof(EdgeType) +  xadj[nVtx]*sizeof(VertexType) + xadj[nVtx]*sizeof(Scalar);

  
  std::cerr<<"Allocating A: "<<Asize<<" ("<<Asize/1024./1024./1024.<<" GB)\n";

  checkCudaErrors( cudaMalloc((void**)&d_row, (nVtx+1)*sizeof(EdgeType)) );
  checkCudaErrors( cudaMalloc((void**)&d_col, xadj[nVtx]*sizeof(VertexType)) );
  checkCudaErrors( cudaMalloc((void**)&d_val, xadj[nVtx]*sizeof(Scalar)) );

  bool uvm = true;


  
  size_t dense_matrix_size = ((size_t)nVtx)* nbvector * sizeof(Scalar);
  std::cerr<<"Allocating B and C: "<<dense_matrix_size<<" ( "<<dense_matrix_size/1024./1024./1024.<<" GB) each\n";
  
  if (!uvm) {
    checkCudaErrors( cudaMalloc((void**)&d_B, dense_matrix_size));
    checkCudaErrors( cudaMalloc((void**)&d_C, dense_matrix_size));
  }
  else {
    checkCudaErrors( cudaMallocManaged((void**)&d_B, dense_matrix_size ) );
    checkCudaErrors( cudaMallocManaged((void**)&d_C, dense_matrix_size ) );

    if (0) {
      int deviceId;
      cudaGetDevice(&deviceId);
      cudaMemLocation gpulocation;
      gpulocation.type = cudaMemLocationTypeDevice;
      gpulocation.id = deviceId;

      cudaMemLocation cpulocation;
      cpulocation.type = cudaMemLocationTypeHostNuma;
      cpulocation.id = 0;
      
      
      size_t gpuchunksize = ((size_t)30000000)*nbvector*sizeof(Scalar);
      size_t cpuchunksize = ((size_t)3554432)*nbvector*sizeof(Scalar);
      
      checkCudaErrors( cudaMemAdvise((void*)d_B, gpuchunksize, cudaMemAdviseSetPreferredLocation, gpulocation ));
      checkCudaErrors( cudaMemAdvise((void*)d_B+gpuchunksize, cpuchunksize, cudaMemAdviseSetPreferredLocation, cpulocation ));
      checkCudaErrors( cudaMemAdvise((void*)d_B+gpuchunksize, cpuchunksize, cudaMemAdviseSetAccessedBy, gpulocation ));
    }
  }

  std::cerr<<"B: "<<d_B<<" C: "<<d_C<<"\n";
  
  cudaMemcpy(d_B, in, nVtx*nbvector*sizeof(Scalar), cudaMemcpyHostToDevice);

  
  

  cudaMemcpy(d_row, xadj, (nVtx+1)*sizeof(EdgeType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_col, adj, xadj[nVtx]*sizeof(VertexType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_val, val, xadj[nVtx]*sizeof(Scalar), cudaMemcpyHostToDevice);

  alpha = 1.0;
  beta = 0.0;


  cusparseStatus = cusparseCreateCsr(&matrixA,
				     nVtx, nVtx, xadj[nVtx],
				     d_row, d_col, d_val,
				     get_cusparse_index_type<EdgeType>(), get_cusparse_index_type<VertexType>(), CUSPARSE_INDEX_BASE_ZERO,
				     get_cusparse_datatype<Scalar>()
				     );
  checkCusparseError(cusparseStatus);
  
  cusparseStatus = cusparseCreateDnMat(&matrixB,
				       nVtx, nbvector,
				       nbvector,
				       d_B, get_cusparse_datatype<Scalar>(),
				       CUSPARSE_ORDER_ROW);
  checkCusparseError(cusparseStatus);
  
  cusparseStatus = cusparseCreateDnMat(&matrixC,
				       nVtx, nbvector,
				       nbvector,
				       d_C, get_cusparse_datatype<Scalar>(),
				       CUSPARSE_ORDER_ROW);
  checkCusparseError(cusparseStatus);

  size_t bsize = -1;
  cusparseStatus = cusparseSpMM_bufferSize(cusparseHandle,
				CUSPARSE_OPERATION_NON_TRANSPOSE, CUSPARSE_OPERATION_NON_TRANSPOSE,
				&alpha,
				(cusparseConstSpMatDescr_t)matrixA, (cusparseConstDnMatDescr_t)matrixB,
				&beta,
				matrixC,
				get_cusparse_datatype<Scalar>(),
				CUSPARSE_SPMM_CSR_ALG2,
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
				    get_cusparse_datatype<Scalar>(),
				    CUSPARSE_SPMM_CSR_ALG2,
				    buffer);
      checkCusparseError(cusparseStatus);
      //std::swap(matrixB, matrixC);
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



