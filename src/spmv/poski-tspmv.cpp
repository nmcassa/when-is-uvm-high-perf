#include "main-tspmv.hpp"
#include <poski.h>

#define THROW_AWAY 10



// /* This example computes SpMV ( y = Ax + y ) with default threading model and partitioning model. */
// #include <stdio.h>
// #include <poski.h>

// int main(int argc, char **argv)
// {
//   /* Initialize pOSKI library */
//   poski_Init();
 
//   /* Initialize Sparse matrix A in CSR format, and dense vectors */
//   int nrows=3; int ncols=3; int nnz=5;
//   int Aptr[4]={0, 1, 3, 5}; int Aind[5]={0, 0, 1, 0, 2}; double Aval[5]={1, -2, 1, 0.5, 1};
//   double x[3]={.25, .45, .65}; double y[3]={1, 1, 1};
//   double alpha = -1, beta = 1;
  
//   /* Create a default thread object {with #threads = #available_cores} */
//   poski_threadarg_t *poski_thread = poski_InitThreads();
  
//   /* Create a tunable-matrix object by wrapping the partitioned sub-matrices using a thread object and a
//      default partition-matrix object {with #partitions = #threads} */
//   poski_mat_t A_tunable =
//     poski_CreateMatCSR ( Aptr, Aind, Aval, nrows, ncols, nnz,/* Sparse matrix A in CSR format */
// 			 SHARE_INPUTMAT,                          /* <matrix copy mode> */
// 			 poski_thread,                            /* <thread object> */
// 			 NULL,                                    /* <partition-matrix object> (NULL: default) */
// 			 2, INDEX_ZERO_BASED, MAT_GENERAL);/* specify how to interpret non-zero pattern */
  
//   /* Create wrappers around the dense vectors with <partition-vector object> (NULL: default) */
//   poski_vec_t x_view = poski_CreateVec(x, 3, STRIDE_UNIT, NULL);
//   poski_vec_t y_view = poski_CreateVec(y, 3, STRIDE_UNIT, NULL);
  
//   /* Partition input/output vectors and Perform matrix vector multiply (SpMV), y = Ax + y */
//   poski_MatMult(A_tunable, OP_NORMAL, alpha, x_view, beta, y_view);
  
//   /* Clean-up interface objects and threads, and shut down pOSKI library */
//   poski_DestroyMat(A_tunable); poski_DestroyVec(x_view); poski_DestroyVec(y_view);
//   poski_DestroyThreads(poski_thread);
//   poski_Close();
  
//   return 0;
// }


template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  //   /* Initialize pOSKI library */
  poski_Init();

  //   /* Create a default thread object {with #threads = #available_cores} */
  poski_threadarg_t *poski_thread = poski_InitThreads();

  char* tt= getenv ("NBTHREADS");
  if (tt != NULL) {
    poski_ThreadHints(poski_thread, NULL, POSKI_THREADPOOL, atoi(tt));
  }

  double alpha = 1, beta = 0;

//   /* Create a tunable-matrix object by wrapping the partitioned sub-matrices using a thread object and a
//      default partition-matrix object {with #partitions = #threads} */
  poski_mat_t A_tunable =
    poski_CreateMatCSR (xadj, adj, val, nVtx, nVtx, xadj[nVtx],/* Sparse matrix A in CSR format */
			SHARE_INPUTMAT,                          /* <matrix copy mode> */
			//COPY_INPUTMAT,                          /* <matrix copy mode> */
			poski_thread,                            /* <thread object> */
			NULL,                                    /* <partition-matrix object> (NULL: default) */
			2, INDEX_ZERO_BASED, MAT_GENERAL);/* specify how to interpret non-zero pattern */
  


  /* Create wrappers around the dense vectors with <partition-vector
     object> (NULL: default) */
  // poski_partitionvec_t *partitionVec1 = poski_PartitionVecHints
  //   (A_tunable,
  //    KERNEL_MatMult, OP_NORMAL, INPUTVEC);
  // poski_partitionvec_t *partitionVec2 = poski_PartitionVecHints
  //   (A_tunable,
  //    KERNEL_MatMult, OP_NORMAL, OUTPUTVEC);
  
  poski_vec_t x_view = poski_CreateVec(in, nVtx, STRIDE_UNIT,
				       NULL);
  poski_vec_t y_view = poski_CreateVec(out, nVtx, STRIDE_UNIT,
				       NULL);
  //  beta, y_view, ALWAYS_TUNE_AGGRESSIVELY);
  



  /* Create wrappers around the dense vectors with <partition-vector object> (NULL: default) */
  //poski_vec_t x_view = poski_CreateVec(in, nVtx, STRIDE_UNIT, NULL);
  //poski_vec_t y_view = poski_CreateVec(out, nVtx, STRIDE_UNIT, NULL);
  
  // std::cerr<<"get ready to tune"<<std::endl;
  // int err = poski_TuneHint_MatMult (A_tunable, OP_NORMAL, alpha, x_view, beta, y_view, ALWAYS_TUNE_AGGRESSIVELY);

  // //  int err = poski_TuneHint_MatMult (A_tunable, OP_NORMAL, alpha,
  // //				    SYMBOLIC_VECTOR, beta, SYMBOLIC_VECTOR, ALWAYS_TUNE_AGGRESSIVELY);


  // if (err != 0) {
  //   std::cerr<<"error in poski_TuneHint_MatMult"<<std::endl;
  // }
  // else {
  //   std::cerr<<"will tune now"<<std::endl;
  //   poski_TuneMat(A_tunable);
  // }
  
  // std::cerr<<"tuned"<<std::endl;

  /* Partition input/output vectors and Perform matrix vector multiply (SpMV), y = Ax + y */
  poski_MatMult(A_tunable, OP_TRANS, alpha, x_view, beta, y_view);

  
  util::timestamp start(0,0);


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      /* Partition input/output vectors and Perform matrix vector multiply (SpMV), y = Ax + y */
      poski_MatMult(A_tunable, OP_TRANS, alpha, x_view, beta, y_view);

    }
  util::timestamp stop;  

  totaltime += stop - start;
  /* Clean-up interface objects and threads, and shut down pOSKI library */
  poski_DestroyMat(A_tunable); poski_DestroyVec(x_view); poski_DestroyVec(y_view);
  poski_DestroyThreads(poski_thread);
  poski_Close();

  return 0;
}



