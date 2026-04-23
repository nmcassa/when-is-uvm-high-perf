#include <string>
#include "graph.hpp"
#include "plot.hpp"


int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  int nCol;
  
  if (argc < 2) {
      fprintf(stderr, "usage: %s <GraphName>\n", argv[0]);
      exit(1);
  }
    

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  
  int* degree = new int[nVtx];

  for (int i = 0; i < nVtx; ++i)
    degree[i] = 0;

  for (int j = 0; j < xadj[nVtx]; ++j)
    ++ degree [adj[j]];

  std::sort(degree, degree+nVtx);

  for (int i=0; i<nVtx;++i)
    std::cout<<i<<" "<<degree[i]<<"\n";
  std::cout<<std::flush;
  


  free(adj);
  free(xadj);
  
  return 0;
}
