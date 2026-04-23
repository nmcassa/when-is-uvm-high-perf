#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <malloc.h>
#include <fstream>
#include <xmmintrin.h>
#include <immintrin.h>

#define THROW_AWAY 0

#include <cuda_runtime_api.h>
#include <cusparse_v2.h>
#include <cublas_v2.h>
#include "helper_cuda.h"


template<typename VertexType, typename EdgeType, typename Scalar>
bool checkGraph(VertexType nVtx, EdgeType* xadj, VertexType *adj, Scalar* val) {
  for (VertexType v = 0; v<nVtx; ++v) {
    assert (xadj[v]>=0);
    assert (xadj[v+1]>=xadj[v]);
    for (EdgeType e = xadj[v]; e < xadj[v+1]; ++e) {
      assert (adj[e] >= 0);
      assert (adj[e] < nVtx);
    }
  }
  return true;
}




template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmm(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out, int nbvector,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out,
	      VertexType nVtx2, EdgeType *xadj2, VertexType *adj2, Scalar *val2, Scalar *in2
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
  cusparseSpMatDescr_t matrixA2 = 0;
  cusparseDnMatDescr_t matrixB = 0;
  cusparseDnMatDescr_t matrixB2 = 0;
    
  cusparseDnMatDescr_t matrixC = 0;

  VertexType *d_col;
  EdgeType *d_row;
  double *d_val;
  double *d_B, *d_B2, *d_C;
  double alpha, beta;

  size_t Asize = (nVtx+1)*sizeof(EdgeType) +  xadj[nVtx]*sizeof(VertexType) + xadj[nVtx]*sizeof(Scalar);

  
  std::cerr<<"Allocating A: "<<Asize<<" ("<<Asize/1024./1024./1024.<<" GB)\n";

  checkCudaErrors( cudaMalloc((void**)&d_row, (nVtx+1)*sizeof(EdgeType)) );
  checkCudaErrors( cudaMalloc((void**)&d_col, xadj[nVtx]*sizeof(VertexType)) );
  checkCudaErrors( cudaMalloc((void**)&d_val, xadj[nVtx]*sizeof(Scalar)) );

  VertexType *d_col2;
  EdgeType *d_row2;
  double *d_val2;

  size_t Asize2 = (nVtx2+1)*sizeof(EdgeType) +  xadj2[nVtx2]*sizeof(VertexType) + xadj2[nVtx2]*sizeof(Scalar);
  std::cerr<<"Allocating A2: "<<Asize2<<" ("<<Asize2/1024./1024./1024.<<" GB)\n";

  checkCudaErrors( cudaMalloc((void**)&d_row2, (nVtx2+1)*sizeof(EdgeType)) );
  checkCudaErrors( cudaMalloc((void**)&d_col2, xadj2[nVtx2]*sizeof(VertexType)) );
  checkCudaErrors( cudaMalloc((void**)&d_val2, xadj2[nVtx2]*sizeof(Scalar)) );

  
  bool uvm = true;


  
  size_t dense_matrix_size = ((size_t)nVtx)* nbvector * sizeof(Scalar);
  std::cerr<<"Allocating B and C: "<<dense_matrix_size<<" ( "<<dense_matrix_size/1024./1024./1024.<<" GB) each\n";
  
  if (!uvm) {
    checkCudaErrors( cudaMalloc((void**)&d_B, dense_matrix_size));
    checkCudaErrors( cudaMalloc((void**)&d_B2, dense_matrix_size));
    checkCudaErrors( cudaMalloc((void**)&d_C, dense_matrix_size));
  }
  else {
    checkCudaErrors( cudaMalloc((void**)&d_B, dense_matrix_size));
    checkCudaErrors( cudaMalloc((void**)&d_C, dense_matrix_size));
    checkCudaErrors( cudaMallocManaged((void**)&d_B2, dense_matrix_size ) );

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
  cudaMemcpy(d_B2, in2, nVtx*nbvector*sizeof(Scalar), cudaMemcpyHostToDevice);

  
  

  cudaMemcpy(d_row, xadj, (nVtx+1)*sizeof(EdgeType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_col, adj, xadj[nVtx]*sizeof(VertexType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_val, val, xadj[nVtx]*sizeof(Scalar), cudaMemcpyHostToDevice);


  cudaMemcpy(d_row2, xadj2, (nVtx2+1)*sizeof(EdgeType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_col2, adj2, xadj2[nVtx2]*sizeof(VertexType), cudaMemcpyHostToDevice);
  cudaMemcpy(d_val2, val2, xadj2[nVtx2]*sizeof(Scalar), cudaMemcpyHostToDevice);

  
  alpha = 1.0;
  beta = 0.0;


  cusparseStatus = cusparseCreateCsr(&matrixA,
				     nVtx, nVtx, xadj[nVtx],
				     d_row, d_col, d_val,
				     get_cusparse_index_type<EdgeType>(), get_cusparse_index_type<VertexType>(), CUSPARSE_INDEX_BASE_ZERO,
				     get_cusparse_datatype<Scalar>()
				     );
  checkCusparseError(cusparseStatus);

  cusparseStatus = cusparseCreateCsr(&matrixA2,
				     nVtx2, nVtx2, xadj2[nVtx2],
				     d_row2, d_col2, d_val2,
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

  cusparseStatus = cusparseCreateDnMat(&matrixB2,
				       nVtx2, nbvector,
				       nbvector,
				       d_B2, get_cusparse_datatype<Scalar>(),
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
      cusparseStatus = cusparseSpMM(cusparseHandle,
				    CUSPARSE_OPERATION_NON_TRANSPOSE, CUSPARSE_OPERATION_NON_TRANSPOSE,
				    &alpha,
				    (cusparseConstSpMatDescr_t) matrixA2, (cusparseConstDnMatDescr_t)matrixB2,
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



int main(int argc, char *argv[])
{
  typedef int64_t VertexType;
  typedef int64_t EdgeType;
  typedef double Scalar;
  
  
  VertexType nVtx, nCol;
  EdgeType nEdge, *xadj;
  VertexType *adj;
  int nTry = 1;
  char *filename = argv[1];
  char timestr[20];
  
  if (argc < 4) {
      fprintf(stderr, "usage: %s <filename1> <filename2> <nbvector> [nTry]\n", argv[0]);
      exit(1);
  }
    
  if (argc >= 5) {
      nTry = atoi(argv[4]);
      if (!nTry) {
          fprintf(stderr, "nTry was 0, setting it to 1\n");
          nTry = 1;
      } 
  } 

  Scalar* val;
  ReadGraph<VertexType,EdgeType,Scalar>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);
  int nbvector = atoi(argv[3]);
  nEdge = xadj[nVtx];

  checkGraph(nVtx, xadj, adj, val);
  

  VertexType nVtx2, nCol2;
  EdgeType nEdge2, *xadj2;
  VertexType *adj2;
  Scalar* val2;
  
  ReadGraph<VertexType,EdgeType,Scalar>(argv[2], &nVtx2, &nCol2, &xadj2, &adj2, &val2, NULL);


  Scalar* in = (Scalar*) _mm_malloc(((size_t)nVtx)*nbvector*sizeof(Scalar), 64);
  Scalar* out = (Scalar*) _mm_malloc(((size_t)nVtx)*nbvector*sizeof(Scalar), 64);


  Scalar* in2 = (Scalar*) _mm_malloc(((size_t)nVtx2)*nbvector*sizeof(Scalar), 64);
  
  for (size_t i=0; i<nVtx*nbvector; ++i)
    in[i] = (Scalar) (i%100);

  //alarm(2400); //most likely our run will not take that long. When the alarm is triggered, there will be no callback to process it and th eprocess will die.

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  util::timestamp totaltime(0,0);  
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_spmm<VertexType,EdgeType,Scalar>(nVtx, xadj, adj, val, in, out, nbvector, nTry, totaltime, algo_out,
					nVtx2, xadj2, adj2, val2, in2);
  
  totaltime /= nTry;
  totaltime.to_c_str(timestr, 20);

  long int totalsize = (size_t)nVtx*nbvector*sizeof(Scalar)*2 //in and out
    +((size_t)nVtx+1)*sizeof(EdgeType)  //xadj
    +((size_t)xadj[nVtx])*(sizeof(VertexType)+sizeof(Scalar)); //adj and val

  std::cout<<"filename: "<<filename
	   <<" filename2: "<<argv[2]
	   <<" nVtx: "<<nVtx
	   <<" nonzero: "<<nEdge
	   <<" nbvector: "<<nbvector
	   <<" AvgTime: "<<(double)totaltime
	   <<" Gflops: "<<2.*nbvector*((double)nEdge)/((double)totaltime)/1000/1000/1000
           <<" Bandwidth: "<<totalsize/((double)totaltime)/1000/1000/1000
	   <<" "<<algo_out<<std::endl;
  




  free(adj);
  free(xadj);
  free(val);
  
  return 0;
}
