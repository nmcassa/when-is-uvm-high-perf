#include "timestamp.hpp"
#include <string>
#include "graph.hpp"
#include <fstream>

#include <xmmintrin.h>



template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      );

typedef int vertex;
typedef int edge;
typedef float value;


int main(int argc, char *argv[])
{
  vertex nVtx, nCol;
  edge nEdge, *xadj;
  vertex *adj;

  int nTry = 1;
  char *filename = argv[1];
  char timestr[20];
  
  if (argc < 2) {
      fprintf(stderr, "usage: %s <filename> [nTry]\n", argv[0]);
      exit(1);
  }
    
  if (argc >= 3) {
      nTry = atoi(argv[2]);
      if (!nTry) {
          fprintf(stderr, "nTry was 0, setting it to 1\n");
          nTry = 1;
      } 
  } 

  value* val;

  ReadGraph<vertex,edge,value>(argv[1], &nVtx, &nCol, &xadj, &adj, &val, NULL);
  //  generateDense<int,int,value>(&nVtx, &nCol, &xadj, &adj, &val, 16*1024);
  //  generateBanded<int,int,value>(&nVtx, &nCol, &xadj, &adj, &val, 16*1024, 128);

  nEdge = xadj[nVtx];

  //  WriteBinary<int,int,value>("foo.bin", nVtx, nCol, xadj, adj, val);
  //  return 0;

  // value* out = new value[nVtx];
  // value* in = new value[nVtx];

  vertex nVtxalloc = nVtx;
  nVtxalloc += 64-(nVtx%64);

  value* out = (value*) _mm_malloc(nVtxalloc*sizeof(value), 64);
  value* in = (value*) _mm_malloc(nVtxalloc*sizeof(value), 64);


  for (vertex i=0; i<nVtx; ++i)
    in[i] = (value) (i%100);

  //alarm(2400); //most likely our run will not take that long. When the alarm is triggered, there will be no callback to process it and th eprocess will die.

  if (strrchr(argv[1], '/'))
      filename = strrchr(argv[1], '/') + 1;
  
  util::timestamp totaltime(0,0);  
  
  std::string algo_out;

  std::cout<<"graph read"<<std::endl;

  main_spmv<vertex,edge,value>(nVtx, xadj, adj, val, in, out, nTry, totaltime, algo_out);
  
  totaltime /= nTry;
  totaltime.to_c_str(timestr, 20);

  size_t totalmemory = nVtx*(sizeof(*in) + sizeof(*out)) + (nVtx+1)*sizeof(*xadj) + xadj[nVtx]*(sizeof(*adj) + sizeof(*val));

  std::cout<<"filename: "<<filename
	   <<" nVtx: "<<nVtx
	   <<" nonzero: "<<nEdge
	   <<" AvgTime: "<<(double)totaltime
	   <<" Gflops: "<<2.*((double)nEdge)/((double)totaltime)/1000/1000/1000
	   <<" Bandwidth: "<<totalmemory/totaltime/1000/1000/1000
	   <<" "<<algo_out<<std::endl;

//   std::ofstream outfile ("a");
//   for (int i=0; i< nVtx; ++i) {
//     outfile<<out[i]<<'\n';
//   }
//   outfile<<std::flush;
//   outfile.close();



  // delete[] in;
  // delete[] out;

  GraphFree<vertex,edge,value> (xadj, adj, val);

  return 0;
}
