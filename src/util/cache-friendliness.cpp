#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <fstream>

#include <xmmintrin.h>


#include "cache-simulator.hpp"

template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* , std::string& algo_out)
{
  int CACHELINE = 64;
  int cache_capacity = 512*1024; //512K

  int datasize = 8; //sizeof(double) in 64 bits


  char* cacheline_str = getenv("CACHELINE");
  if (cacheline_str != NULL) {
    CACHELINE=atoi(cacheline_str);
  }
  else
    std::cerr<<"CACHELINE defaults to "<<CACHELINE<<std::endl;

  char* cache_capacity_str = getenv("cache_capacity");
  if (cache_capacity_str != NULL) {
    cache_capacity=atoi(cache_capacity_str);
  }
  else
    std::cerr<<"cache_capacity defaults to "<<cache_capacity<<std::endl;


  char* datasize_str = getenv("datasize");
  if (datasize_str != NULL) {
    datasize=atoi(datasize_str);
  }
  else
    std::cerr<<"datasize defaults to "<<datasize<<std::endl;


  CacheSimulatorFast cs (CACHELINE, cache_capacity);

  for (VertexType i = 0; i < nVtx; ++i)
    {
      if (i % 500 == 0) {
	std::cout<<"progress: "<<i<<"/"<<nVtx<<" vertices "<<xadj[i]<<"/"<<xadj[nVtx]<<" edges. Hit ratio: "<<cs.getHitRatio()<<std::endl;
      }

      VertexType* beg = adj+xadj[i];
      VertexType* end = adj+xadj[i+1];
      for (auto p = beg; p < end; ++p)
	{
	  EdgeType address = (*p * datasize);
	  cs.touch(address);
	}
    }

  std::stringstream ss;
  ss<<"CacheMiss: "<<cs.getMiss()
    <<" Friendliness: "<<cs.getHitRatio()
    <<" CACHELINE: "<<CACHELINE
    <<" cache_capacity: "<<cache_capacity
    <<" datasize: "<<datasize;

  
  algo_out = ss.str();


  return 0;
}


int main(int argc, char *argv[])
{
  int nVtx, nCol, nEdge, *xadj, *adj;
  char *filename = argv[1];
  
  if (argc < 2) {
      fprintf(stderr, "usage: %s <filename>\n", argv[0]);
      fprintf(stderr, "consider the following environment variables : CACHELINE, cache_capacity and datasize\n");
      exit(1);
  }

  float* val;

  ReadGraph<int,int,float>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);

  nEdge = xadj[nVtx];

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_spmv<int,int,float>(nVtx, xadj, adj, val, algo_out);
  

  std::cout<<"filename: "<<filename
	   <<" nVtx: "<<nVtx
	   <<" nonzero: "<<nEdge
	   <<" "<<algo_out<<std::endl;


  GraphFree(xadj, adj, val);

  return 0;
}
