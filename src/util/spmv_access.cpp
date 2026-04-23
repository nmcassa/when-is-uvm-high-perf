#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <fstream>

#include <xmmintrin.h>


#include <sstream>
#include <algorithm>


#include <list>

template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, std::string& algo_out)
{
  int CACHELINE = 64;

  int datasize = 8; //sizeof(double) in 64 bits

  char* cacheline_str = getenv("CACHELINE");
  if (cacheline_str != NULL) {
    CACHELINE=atoi(cacheline_str);
  }
  else
    std::cerr<<"CACHELINE defaults to "<<CACHELINE<<std::endl;

  char* datasize_str = getenv("datasize");
  if (datasize_str != NULL) {
    datasize=atoi(datasize_str);
  }
  else
    std::cerr<<"datasize defaults to "<<datasize<<std::endl;


  int cache_capacity = 512*1024; //512K
  char* cache_capacity_str = getenv("cache_capacity");
  if (cache_capacity_str != NULL) {
    cache_capacity=atoi(cache_capacity_str);
  }
  else
    std::cerr<<"cache_capacity defaults to "<<cache_capacity<<std::endl;

  int blocksize = 64;
  int block_mult = 60;

  int miss = 0;

  int cache_capacity_in_lines = cache_capacity / CACHELINE;
   


  for (int core = 0; core < block_mult; core++)
  {

    std::list<VertexType> LRUorder;

    
    for (int bl = 0; (core+bl*block_mult)*blocksize<nVtx; bl++)
      {
	int block_beg=(core+bl*block_mult)*blocksize;
	for (VertexType i = block_beg; i < std::min(block_beg+blocksize,nVtx); i++)
	  {
	    VertexType* beg = adj+xadj[i];
	    VertexType* end = adj+xadj[i+1];
	    for (auto p = beg; p < end; ++p)
	      {
		VertexType block = (*p * datasize) / CACHELINE;
		
		auto it = std::find (LRUorder.begin(), LRUorder.end(), block);
		if (it == LRUorder.end())
		  {
		    //not found
		    miss++;
		    LRUorder.push_back(block);
		    if (LRUorder.size() > cache_capacity_in_lines)
		      {
			LRUorder.pop_front();
		      }
		  }
		else
		  {
		    //it is there, put it on the front.
		    LRUorder.erase(it);
		    LRUorder.push_back(block);
		  }  
		
	      }
	  }
      }
    
  }

  std::stringstream ss;
  ss<<"miss: "<<miss
    <<" ratio: "<<miss/((float)(ceil(((float)nVtx)*datasize/CACHELINE)));

  
  algo_out = ss.str();


  return 0;
}


int main(int argc, char *argv[])
{
  int nVtx, nCol, nEdge, *xadj, *adj;
  char *filename = argv[1];
  
  if (argc < 2) {
      fprintf(stderr, "usage: %s <filename>\n", argv[0]);
      fprintf(stderr, "consider the following environment variable CACHELINE cache_capacity datasize\n");
      exit(1);
  }

  double* val;

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);

  nEdge = xadj[nVtx];

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_spmv<int,int,double>(nVtx, xadj, adj, val, algo_out);
  

  std::cout<<"filename: "<<filename
	   <<" nVtx: "<<nVtx
	   <<" nonzero: "<<nEdge
	   <<" "<<algo_out<<std::endl;


  GraphFree(xadj, adj, val);

  return 0;
}
