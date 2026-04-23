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
  bool should_sort_adj = false;


  if (argc != 4)
    {
      std::cerr<<"usage : "<<argv[0]<<" <filename> <ordering> <output>"<<std::endl;
      std::cerr<<"<filename> points to a graphs in the .graph or .mtx format"<<std::endl;
      std::cerr<<"<ordering> can be 1 for random shuffle, 2 for Breadth first search, 3 for patoh(if compiled in)"<<std::endl;
      std::cerr<<"<out> can be 1 for chaco format or 2 for mtx (all values will be 1.000)"<<std::endl;
      return -1;
    }

  int nCol;
  ReadGraph<vertex, edge, double/*don't care about weight*/>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  int permuttype = atoi(argv[2]); //1 is shuffle, 2 is BFS, 3 is patoh
  int outputtype = atoi(argv[3]);

  if (outputtype != 1 && outputtype != 2)
    {
      std::cerr<<"unknown output format"<<std::endl;
      return -1;
    }

  nVtx;
  nEdge = xadj[nVtx];  

  //srand(time(NULL));

  int * permut = new int[nVtx]; //permut[i] is the new id of old i

  if (permuttype == 1)
    {
      //random shuffle
      std::cerr<<"shuffling..."<<std::endl;
      for (int i=0; i< nVtx; i++)
	{
	  permut[i] = i;
	}

      shuffle(permut, nVtx);
      std::cerr<<"shuffled"<<std::endl;
      should_sort_adj = false;
    }
  else if (permuttype == 2)
    {
      std::cerr<<"computing BFS"<<std::endl;
      BreadthFirstSearch(nVtx, adj, xadj, permut);
      should_sort_adj = true;
      std::cerr<<"BFS obtained"<<std::endl;
    }
#ifdef HAVE_PATOH_
  else if (permuttype == 3)
    {
      hypergraph(nVtx, adj, xadj, permut);
      should_sort_adj = true;
    }
#endif

    


  //build a new graph

  edge* new_xadj = new edge[nVtx+1];
  vertex* new_adj = new vertex[nEdge];

  std::cerr<<"permuting"<<std::endl;

  permutegraph<vertex, edge>(nVtx, xadj, adj, permut, new_xadj, new_adj, should_sort_adj);

  std::cerr<<"outputing"<<std::endl;

  
  if (outputtype == 1)
    {
      //output the graph in chaco format
      std::cout<<nVtx<<" "<<nEdge/2<<std::endl; //chaco banner
      
      for (int i=0; i<nVtx; i++)
	{
	  int new_u = i;
	  
	  assert (new_u >= 0);
	  assert (new_u < nVtx);
	  
	  for (int j=new_xadj[new_u]; j<new_xadj[new_u+1]; j++)
	    {
	      int new_v = new_adj[j];
	      assert (new_v >= 0);
	      assert (new_v < nVtx);
	      std::cout<<new_v+1<<" ";
	    }
	  std::cout<<'\n';
	}
      std::cout<<std::flush;
    }
  else if (outputtype == 2)
    {
      //output the graph in chaco format
      
      std::cout<<"%%MatrixMarket matrix coordinate real general"<<std::endl;
      std::cout<<nVtx<<' '<<nVtx<<' '<<new_xadj[nVtx]<<std::endl;

      for (int i=0; i<nVtx; i++)
	{
	  int new_u = i;
	  
	  assert (new_u >= 0);
	  assert (new_u < nVtx);
	  
	  for (int j=new_xadj[new_u]; j<new_xadj[new_u+1]; j++)
	    {
	      int new_v = new_adj[j];
	      assert (new_v >= 0);
	      assert (new_v < nVtx);
	      std::cout<<new_u+1<<' '<<new_v+1<<' '<<1.<<'\n';
	    }
	}
      std::cout<<std::flush;
    }
  
  free(xadj);
  free(adj);
  delete[] permut;
  delete[] new_adj;
  delete[] new_xadj;
  return 0;
}
