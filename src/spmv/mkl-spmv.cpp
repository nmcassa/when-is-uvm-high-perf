#include "main-spmv.hpp"
#include <mkl.h>

#define THROW_AWAY 10



template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  char orientation='N';

  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      if (sizeof(Scalar) == 8)
	mkl_dcsrgemv (&orientation,
		      &nVtx, val, xadj, adj,
		      in, out);
      

    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



