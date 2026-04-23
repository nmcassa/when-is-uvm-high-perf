#include "ulib.h"
#include <algorithm>
#include <iostream>
#include "graph.hpp"
#include <assert.h>
#include <deque>
#include "graphshuffler.hpp"

typedef int vertex;
typedef int edge;
typedef float value;

int main (int argc, char* argv[])
{
  vertex nVtx;
  edge nEdge;
  edge* xadj;
  vertex* adj;

  value* elements;

  bool should_sort_adj = false;

  if (argc != 3)
    {
      std::cerr<<"usage : "<<argv[0]<<" <filenamein> <filenameout>"<<std::endl;
      std::cerr<<"<filename> points to a graphs in the .graph or .mtx format"<<std::endl;
      return -1;
    }

  int nCol;
  ReadGraph<vertex, edge, value>(argv[1], &nVtx, &nCol, &xadj, &adj, &elements, NULL);

  nEdge = xadj[nVtx];  

  if (elements == NULL) {
    elements = new value [nEdge];
    for (edge i=0; i<nEdge; ++i) {
      elements[i] = 1.0;
    }
  }

  WriteBinary (argv[2], nVtx, nCol, xadj, adj, elements);

  GraphFree(xadj, adj, elements);

  return 0;
}
