
/* mkl.h is required for dsecnd and DGEMM */
#include <mkl.h>
#include <stdio.h>

int main ()
{
  const int LOOP_COUNT=300;
  int m = 384;
  int n = m;
  int k = m;

  double* A = new double [m*k];
  double* B = new double [k*n];
  double* C = new double [m*k];
  
  

  double alpha = 1.0, beta = 1.0;
  /* first call which does the thread/buffer initialization */
  DGEMM("N", "N", &m, &n, &k, &alpha, A, &m, B, &k, &beta, C, &m);
  /* start timing after the first GEMM call */
  double time_st = dsecnd();
  for (int i=0; i<LOOP_COUNT; ++i)
    {
      DGEMM("N", "N", &m, &n, &k, &alpha, A, &m, B, &k, &beta, C, &m);
    }
  double time_end = dsecnd();
  double time_avg = (time_end - time_st)/LOOP_COUNT;
  double gflop = (2.0*m*n*k)*1E-9;

  printf("Average time: %.3f secs \n", time_avg);
  printf("Op Count    : %.3f  \n", gflop);
  printf("GFlops      : %.3f  \n,", gflop/time_avg); 
  
  return 0;
}
