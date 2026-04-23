#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <fstream>
#include <sstream>

#include <xmmintrin.h>


#include <sstream>
#include <algorithm>


#include <list>



template<typename VtxType, typename EdgeCount>
void filter_graph (VtxType nVtx, const EdgeCount* xadj, const VtxType* adj, const bool* edgemark, EdgeCount* new_xadj, VtxType* new_adj) {
  new_xadj[0] = 0;
  
  for (VtxType u = 0; u< nVtx; ++u) {
    new_xadj[u+1] = new_xadj[u];
    for (EdgeCount ptr = xadj[u]; ptr != xadj[u+1]; ++ptr) {
      if (edgemark[ptr]) {
	new_adj[new_xadj[u+1]] = adj[ptr];
	++new_xadj[u+1];
      }
    }      
  }
}

//return -1 for notfound
template<typename VtxType, typename EdgeCount>
EdgeCount find_edge(VtxType u, VtxType v, VtxType nVtx, EdgeCount* xadj, VtxType* adj) {
  
  for (auto ptr = xadj[u]; ptr< xadj[u+1]; ++ptr) {
    if (adj[ptr] == v) return ptr;
  }

  return -1;
}

//return random number in [min;max]
int myrand (int min, int max) {
  if (min == max) return min;
  assert (min < max);

  int r = rand();
  return (max+1-min)*((double)r/((double)RAND_MAX+1))+min;
}

int main(int argc, char *argv[])
{
  int nVtx, nCol, nEdge, *xadj, *adj;
  char *filename = argv[1];
  
  if (argc - 1 != 4) {
      fprintf(stderr, "usage: %s <filename_in> <chaco_out> <edge_list> <nbedge_to_remove>\n", argv[0]);
      exit(1);
  }

  double* val;

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);

  nEdge = xadj[nVtx];

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  std::cout<<"marking"<<std::endl;

  int nbedge_to_remove = atoi(argv[4]);

  bool* edgemark = new bool[nEdge];
  for (int i=0; i<nEdge; ++i)
    edgemark [i] = true;

  for (int e = 0; e< nbedge_to_remove; ++e) {
    int u = myrand (0, nVtx-1);
    if (xadj[u] == xadj[u+1]) continue;
    int ptr = myrand (xadj[u], xadj[u+1]-1);
    edgemark[ptr] = false;
    int v = adj[ptr];
    int reverse_edge = find_edge(v,u,nVtx, xadj, adj);
    assert (reverse_edge != -1);
    edgemark[reverse_edge]= false;
  }
  
  int* new_xadj = new int [nVtx+1];
  int* new_adj = new int [nEdge];

  std::cout<<"filtering"<<std::endl;

  filter_graph (nVtx, xadj, adj, edgemark, new_xadj, new_adj);

  std::cout<<"outputting"<<std::endl;

  WriteChaco<int,int,double> (argv[2], nVtx, nVtx, new_xadj, new_adj, NULL);

  {
    std::ofstream edgeout (argv[3]);
    for (int u=0; u<nVtx; ++u) {
      for (auto ptr = xadj[u]; ptr != xadj[u+1]; ++ptr) {
	if (!edgemark[ptr]) {
	  int v = adj[ptr];
	  edgeout<<u<<" "<<v<<std::endl;
	  edgemark[ptr] = true;
	  int reverse_edge = find_edge(v, u, nVtx, xadj, adj);
	  assert (reverse_edge != -1);
	  edgemark[reverse_edge] = true;
	}
      }
    }
  }

  GraphFree(xadj, adj, val);

  return 0;
}
