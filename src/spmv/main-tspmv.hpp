#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <xmmintrin.h>



template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      );

int main(int argc, char *argv[])
{
  int nVtx, nCol, nEdge, *xadj, *adj, nTry = 1;
  char *filename = argv[1];
  char timestr[20];
  
  if (argc < 2) {
      fprintf(stderr, "usage: %s <filename> [nTry]\n", argv[0]);
      exit(1);
  }
    
  if (argc >= 3) {
      nTry = atoi(argv[2]);
      if (!nTry) {
          fprintf(stderr, "nTry was 0, setting it to 1\n");
          nTry = 1;
      } 
  } 

  double* val;
  util::timestamp read_start;
  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);
  nEdge = xadj[nVtx];
  util::timestamp read_end;
  std::cerr<<"It took "<<read_end-read_start<<" seconds to read"<<std::endl;

  // double* out = new double[nVtx];
  // double* in = new double[nVtx];

  double* out = (double*) _mm_malloc(nVtx*sizeof(double), 64);
  double* in = (double*) _mm_malloc(nVtx*sizeof(double), 64);


  for (int i=0; i<nVtx; ++i)
      in[i] = 1.;

  //alarm(2400); //most likely our run will not take that long. When the alarm is triggered, there will be no callback to process it and th eprocess will die.

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  util::timestamp totaltime(0,0);  
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_tspmv<int,int,double>(nVtx, xadj, adj, val, in, out, nTry, totaltime, algo_out);
  
  totaltime /= nTry;
  totaltime.to_c_str(timestr, 20);

  std::cout<<"filename: "<<filename
	   <<" nVtx: "<<nVtx
	   <<" nonzero: "<<nEdge
	   <<" AvgTime: "<<(double)totaltime
	   <<" Gflops: "<<2.*((double)nEdge)/((double)totaltime)/1000/1000/1000
	   <<" "<<algo_out<<std::endl;
  


  // delete[] in;
  // delete[] out;

  free(adj);
  free(xadj);
  free(val);
  
  return 0;
}
