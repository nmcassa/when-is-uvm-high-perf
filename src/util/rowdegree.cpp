#include <string>
#include "graph.hpp"
#include "plot.hpp"


int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  int nCol;
  
  if (argc < 1) {
    std::cerr<<"usage: "<<argv[0]<<" <GraphName>"<<std::endl;
    std::cerr<<"if the environment variable NOSORT is set then the degrees are returned as is."<<std::endl;
      
      exit(1);
  }
    

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  
  int* degree = new int[nVtx];
  for (int i=0; i<nVtx;++i)
    degree[i] = xadj[i+1]-xadj[i];

  if (!getenv("NOSORT"))
    std::sort(degree, degree+nVtx);

  for (int i=0; i<nVtx;++i)
    std::cout<<i<<" "<<degree[i]<<"\n";
  std::cout<<std::flush;
  


  free(adj);
  free(xadj);
  
  return 0;
}
