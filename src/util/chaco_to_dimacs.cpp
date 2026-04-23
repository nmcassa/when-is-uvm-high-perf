
#include "timestamp.hpp"
#include "graph.hpp"

int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  char *filename = argv[1];
  char timestr[20];
  
  if (argc < 2) {
    fprintf(stderr, "usage: %s <filename> [nTry]\n", argv[0]);
    exit(1);
  }
  
  ReadGraph<int,int, int>(argv[1], &nVtx, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  if (strrchr(argv[1], '/'))
    filename = strrchr(argv[1], '/') + 1;

  std::cout<<"p sp "<<nVtx<<" "<<xadj[nVtx]<<std::endl;
  for (long int u=0; u<nVtx; u++)
    {
      for (long int j=xadj[u]; j<xadj[u+1]; j++)
	{
	  long int v = adj[j];
	  std::cout<<"a "<<u+1<<" "<<v+1<<" "<<1<<std::endl;
	}
    }


  delete[] adj;
  delete[] xadj;

  return 0;
}
