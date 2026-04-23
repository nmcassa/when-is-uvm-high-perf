#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <malloc.h>
#include <fstream>
#include <xmmintrin.h>


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
	      util::timestamp& totaltime, std::string& algo_out
	      );

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
  
  if (argc < 3) {
      fprintf(stderr, "usage: %s <filename> <nbvector> [nTry]\n", argv[0]);
      exit(1);
  }
    
  if (argc >= 4) {
      nTry = atoi(argv[3]);
      if (!nTry) {
          fprintf(stderr, "nTry was 0, setting it to 1\n");
          nTry = 1;
      } 
  } 

  Scalar* val;
  ReadGraph<VertexType,EdgeType,Scalar>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);
  int nbvector = atoi(argv[2]);
  nEdge = xadj[nVtx];

  checkGraph(nVtx, xadj, adj, val);
  
  
  Scalar* in = (Scalar*) _mm_malloc(((size_t)nVtx)*nbvector*sizeof(Scalar), 64);
  Scalar* out = (Scalar*) _mm_malloc(((size_t)nVtx)*nbvector*sizeof(Scalar), 64);

  
  for (size_t i=0; i<nVtx*nbvector; ++i)
    in[i] = (Scalar) (i%100);

  //alarm(2400); //most likely our run will not take that long. When the alarm is triggered, there will be no callback to process it and th eprocess will die.

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  util::timestamp totaltime(0,0);  
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_spmm<VertexType,EdgeType,Scalar>(nVtx, xadj, adj, val, in, out, nbvector, nTry, totaltime, algo_out);
  
  totaltime /= nTry;
  totaltime.to_c_str(timestr, 20);

  long int totalsize = (size_t)nVtx*nbvector*sizeof(Scalar)*2 //in and out
    +((size_t)nVtx+1)*sizeof(EdgeType)  //xadj
    +((size_t)xadj[nVtx])*(sizeof(VertexType)+sizeof(Scalar)); //adj and val

  std::cout<<"filename: "<<filename
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
