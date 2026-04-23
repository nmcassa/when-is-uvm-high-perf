#include "ulib.h"
#include <algorithm>
#include <iostream>
#include "graph.hpp"
#include <assert.h>
#include <deque>
#include "graph_part.hpp"

typedef int vertex;
typedef int edge;

int main (int argc, char* argv[])
{
  int nVtx;
  int* xadj;
  int* adj;


  if (argc != 3)
    {
      std::cerr<<"usage : "<<argv[0]<<" <filename> <nbpart>"<<std::endl;
      std::cerr<<"<filename> points to a graphs in the .graph or .mtx format"<<std::endl;
      return -1;
    }

  int nCol;
  ReadGraph<vertex, edge, double/*don't care about weight*/>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);

  int * part = new int[nVtx]; 

  hypergraph(nVtx, adj, xadj, part, atoi(argv[2]));
    
  for (int i=0; i< nVtx; ++i)
    std::cout<<part[i]<<std::endl;

  GraphFree<vertex, edge, double>(xadj, adj, NULL);
  delete[] part;
  return 0;
}
