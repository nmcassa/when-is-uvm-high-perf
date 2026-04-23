#include "ulib.h"
#include <algorithm>
#include <iostream>
#include "graph.hpp"
#include <assert.h>
#include <deque>
#include "graphshuffler.hpp"

typedef int vertex;
typedef int edge;

int main (int argc, char* argv[])
{
  int nVtx;
  int nEdge;
  int* xadj;
  int* adj;
  double *elements;
  bool should_sort_adj = false;


  if (argc != 2)
    {
      std::cerr<<"usage : "<<argv[0]<<" <filenamein> <filenameout>"<<std::endl;
      std::cerr<<"<filename> points to a graphs in the .graph or .mtx format"<<std::endl;
      return -1;
    }

  int nCol;
  ReadGraph<vertex, edge, double>(argv[1], &nVtx, &nCol, &xadj, &adj, &elements, NULL);

  nEdge = xadj[nVtx];  

  std::cout<<"graph graphname {"<<std::endl;
  for (vertex u = 0; u<nVtx; ++u) {
    for (edge p = xadj[u]; p!=xadj[u+1]; ++p) {
      vertex v = adj[p];
      std::cout<<u<<" -- "<<v<<";"<<std::endl;
    }
  }
  std::cout<<"}"<<std::endl;

  GraphFree(xadj, adj, elements);

  return 0;
}
