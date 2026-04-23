#include <string>
#include "graph.hpp"
#include "plot.hpp"


int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  int nCol;
  
  if (argc < 3) {
      fprintf(stderr, "usage: %s <GraphName> <ImgFilename> <ImgSize>\n", argv[0]);
      exit(1);
  }
    

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  
  plot<int,int,double>(atoi(argv[3]), atoi(argv[3]),
		       nVtx, nVtx, xadj, adj, 
		       argv[2]);
  


  free(adj);
  free(xadj);
  
  return 0;
}
