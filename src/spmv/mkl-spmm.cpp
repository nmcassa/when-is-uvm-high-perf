#include "main-spmm.hpp"
#include <mkl.h>


#define THROW_AWAY 10

template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmm(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out, int nbvector,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  totaltime = util::timestamp(0,0);
  util::timestamp start(0,0);

  char orientation='N';
  double alpha = 1.;
  double beta = 0.;

  char * matdescra= "GXXCXX";// http://software.intel.com/sites/products/documentation/doclib/mkl_sa/11/mklman/GUID-34C8DB79-0139-46E0-8B53-99F3BEE7B2D4.htm#TBL2-6

  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      
      mkl_dcsrmm (&orientation,
		  &nVtx, &nbvector, &nVtx,
		  &alpha, matdescra,
		  val,  adj, xadj, xadj+1,
		  in, &nbvector, 
		  &beta, out, &nbvector
		  );


    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



