#include <iostream>
#include "graph.hpp"
#include <map>
#include <string>

int main(int argc, char* argv[]) {

  typedef int VtxType;
  typedef long int EdgeIndex;
  
  if (argc < 4) {
    std::cerr<<"Usage : "<<argv[0]<<" <edgelist> <chacoout> <mapout>"<<std::endl;
    return -1;
  }

  std::string filename_in = argv[1];
  std::string graph_out = argv[2];
  std::string map_out = argv[3];

  std::map<std::string, VtxType> namemap;

  VtxType nbvertex;
  EdgeIndex *xadj = NULL;
  VtxType *adj = NULL;

  
  ReadEdgeList<VtxType, EdgeIndex> (filename_in, &nbvertex, &xadj, &adj, namemap, true);

  WriteChaco<VtxType, EdgeIndex, VtxType> (graph_out.c_str(), nbvertex, nbvertex, xadj, adj, (VtxType*)NULL);

  {
    std::ofstream out (map_out);
    for (auto pa : namemap) 
      out<<pa.first<<" "<<pa.second+1<<std::endl; //chaco is offset by 1
    
  }
  
  delete[] xadj;
  delete[] adj;


  return 0;

}
