#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <iostream>
#include <fstream>

int main(int argc, char *argv[])
{
  typedef int64_t VertexType;
  typedef int64_t EdgeType;
  typedef double Scalar;
  
  
  VertexType nVtx, nCol,  *adj;
  EdgeType *xadj;

  Scalar* val;

  if (argc < 3)
    {
      std::cerr<<"usage: "<<argv[0]<<" <outputChaco> <type> [param0] [param1] [param2] ..."<<std::endl;
      std::cerr<<"        "<<"btree <depth>"<<std::endl;
      std::cerr<<"        "<<"bandedmatrix <nvertex> <bandsize>"<<std::endl;
      std::cerr<<"        "<<"RegularSpaced <size> <degree> <spacing>"<<std::endl;
      std::cerr<<"        "<<"RegularRandom <size> <degree>"<<std::endl;
      std::cerr<<"        "<<"HotRegularSpaced <size> <every> <degree> <spacing>"<<std::endl;
      std::cerr<<"        "<<"RandomDiag <sizeR> <degree> <sizeD> <blocksize>"<<std::endl;
      std::cerr<<"        "<<"clippeddiagonal <size> <clip>"<<std::endl;
      return -1;
    }

  std::stringstream scmd;
  scmd << argv[2];

  std::string cmd = scmd.str();

  srand(time(NULL));

  if (cmd == "btree")
    generateBinaryTree<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]));
  else if (cmd == "RegularSpaced")
    generateRegularSpaced<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]), atol(argv[5]));
  else if (cmd == "RegularSpacedNoCache")
    generateRegularSpacedNoCache<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]), atol(argv[5]));
  else if (cmd == "RegularRandom")
    generateRegularRandom<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]));
  else if (cmd == "HotRegularSpaced")
    generateHotRegularSpaced<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]), atol(argv[5]), atol(argv[6]));
  else if (cmd == "HotRegularSpacedNoCache")
    generateHotRegularSpacedNoCache<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]), atol(argv[5]), atol(argv[6]));
  else if (cmd == "densematrix")
    generateDense<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]));
  else if (cmd == "bandedmatrix")
    generateBanded<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]));
  else if (cmd == "cycle")
    generateCycle<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]));
  else if (cmd == "RandomDiag")
    generateRandomPlusDegOneBlocked<VertexType, EdgeType, Scalar>
      (&nVtx, &nCol, &xadj, &adj, &val,
       atol(argv[3]), atol(argv[4]), atol(argv[5]), atoi(argv[6]));
  else if (cmd == "clippeddiagonal")
    generateClipedDiagonal<VertexType, EdgeType, Scalar>(&nVtx, &nCol, &xadj, &adj, &val, atol(argv[3]), atol(argv[4]));
  else
    std::cerr<<"unknown generator"<<std::endl;

  checkGraphCoherency(nVtx, nCol, xadj, adj, val);
  
  //  WriteChaco<VertexType, EdgeType, Scalar>(argv[1], nVtx, nCol, xadj, adj, val );
  WriteGraph<VertexType, EdgeType, Scalar>(argv[1], nVtx, nCol, xadj, adj, val );

  return 0;
}
