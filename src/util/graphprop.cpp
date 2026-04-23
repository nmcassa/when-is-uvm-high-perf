#include <string>
#include "graph.hpp"
#include "plot.hpp"


int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  int nCol;
  
  if (argc < 1) {
      fprintf(stderr, "usage: %s <GraphName>\n", argv[0]);
      exit(1);
  }
    

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  
  // plot<int,int,double>(atoi(argv[3]), atoi(argv[3]),
  // 		       nVtx, nVtx, xadj, adj, 
  // 		       argv[2]);
  
  int* degree = new int[nVtx];
  for (int i=0; i<nVtx;++i)
    degree[i] = xadj[i+1]-xadj[i];
  
  std::sort(degree, degree+nVtx);
  
  
  
  
  int* degreeC = new int[nVtx];

  for (int i = 0; i < nVtx; ++i)
    degreeC[i] = 0;

  for (int j = 0; j < xadj[nVtx]; ++j)
    ++ degreeC [adj[j]];

  std::sort(degreeC, degreeC+nVtx);



  std::cerr<<"nrow ncol nnz dens avgdegrow avgdegcol maxdegrow maxdegcol"<<std::endl;
  std::cout<<nVtx<<" "
	   <<nCol<<" "
	   <<xadj[nVtx]<<" "
	   <<((double)xadj[nVtx])/(((double)nVtx)*nCol)<<" "
	   <<((double)xadj[nVtx])/nVtx<<" "
	   <<((double)xadj[nVtx])/nCol<<" "
	   <<degree[nVtx-1]<<" "
	   <<degreeC[nVtx-1]<<std::endl;

  free(adj);
  free(xadj);
  
  return 0;
}
