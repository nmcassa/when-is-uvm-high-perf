#include <string>
#include "graph.hpp"

template<typename VertexType, typename EdgeType>
void block (VertexType MatSizeX, VertexType MatSizeY, EdgeType*xadj, VertexType *adj,
	    int BR, int BC, long int* occurence)
{

  int nbcolblock = ceil((double)MatSizeY/BC);
  int * blockoc = new int[nbcolblock];

  for (int i=0; i< nbcolblock; ++i)
    blockoc[i] = 0;

  for (VertexType x = 0; x< MatSizeX; ++x) {
    
    VertexType* beg = adj+xadj[x];
    VertexType* end = adj+xadj[x+1];
    for (auto p = beg; p < end; ++p)
      {
	VertexType y = *p;
	int yloc = y/BC;
	
	++blockoc[yloc];
      }

    if ((x+1)%BR == 0 || (x == MatSizeX-1)) {
      for (int i=0; i< nbcolblock; ++i) {
	assert (blockoc[i] >= 0);
	assert (blockoc[i] <= BR*BC);

	++occurence[blockoc[i]];
	blockoc[i] = 0;
      }

    }

  }
  

  delete[] blockoc;
}


int main(int argc, char *argv[])
{
  int nVtx, nEdge, *xadj, *adj;
  int nCol;
  
  if (argc < 3) {
      fprintf(stderr, "usage: %s <GraphName> <BR> <BC>\n", argv[0]);
      exit(1);
  }
    

  ReadGraph<int,int,double>(argv[1], &nVtx, &nCol, &xadj, &adj, NULL, NULL);
  nEdge = xadj[nVtx];
  
  int BR = atoi(argv[2]);
  int BC = atoi(argv[3]);
  
  long int* occurence = new long int [BR*BC+1]; //occurence[i] will store the number of blocks with i non zero in it

  for (int i=0; i<BR*BC+1; ++i)
    occurence[i] = 0;

  block<int,int>(nVtx, nCol, xadj, adj, BR, BC, occurence);
  
  
  long int nonzeroblock = 0;

  for (int i=1; i<BR*BC+1; ++i)
    nonzeroblock += occurence[i];

  double blockdensity = 0;

  for (int i=1; i<BR*BC+1; ++i)
    blockdensity += i * occurence[i];
  blockdensity /= nonzeroblock;

  std::cout<<"# nbnnzblock: "<<nonzeroblock<<" blockdensity: "<<blockdensity<<" normalizedblockdensity: "<<blockdensity/(BR*BC)<<std::endl;

  for (int i=0; i<BR*BC+1; ++i)
    std::cout<<i<<" "<<occurence[i]<<std::endl;


  GraphFree<int, int, double>(xadj, adj);

  delete[] occurence;
  
  return 0;
}
