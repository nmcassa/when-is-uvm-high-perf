#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <iostream>
#include <fstream>

int main(int argc, char *argv[])
{
  int nVtx, nCol, *xadj, *adj;

  double* val;

  if (argc < 3)
    {
      std::cerr<<"usage: "<<argv[0]<<" <outputChaco> <type> [param0] [param1] [param2] ..."<<std::endl;
      std::cerr<<"        "<<"btree <depth>"<<std::endl;
      std::cerr<<"        "<<"RegularSpaced <size> <degree> <spacing>"<<std::endl;
      std::cerr<<"        "<<"RegularRandom <size> <degree>"<<std::endl;
      std::cerr<<"        "<<"HotRegularSpaced <size> <every> <degree> <spacing>"<<std::endl;
      return -1;
    }

  std::stringstream scmd;
  scmd << argv[2];

  std::string cmd = scmd.str();

  srand(time(NULL));

  if (cmd == "btree")
    generateBinaryTree<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]));
  else if (cmd == "RegularSpaced")
    generateRegularSpaced<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
  else if (cmd == "RegularSpacedNoCache")
    generateRegularSpacedNoCache<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
  else if (cmd == "RegularRandom")
    generateRegularRandom<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]));
  else if (cmd == "HotRegularSpaced")
    generateHotRegularSpaced<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), atoi(argv[6]));
  else if (cmd == "HotRegularSpacedNoCache")
    generateHotRegularSpacedNoCache<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), atoi(argv[6]));
  else if (cmd == "densematrix")
    generateDense<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]));
  else if (cmd == "bandedmatrix")
    generateBanded<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]), atoi(argv[4]));
  else if (cmd == "cycle")
    generateCycle<int,int,double>(&nVtx, &nCol, &xadj, &adj, &val, atoi(argv[3]));
  else
    std::cerr<<"unknown generator"<<std::endl;


  
  //  WriteChaco<int,int,double>(argv[1], nVtx, nCol, xadj, adj, val );
  WriteGraph<int,int,double>(argv[1], nVtx, nCol, xadj, adj, val );

  return 0;
}
