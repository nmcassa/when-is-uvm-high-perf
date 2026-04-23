#include "main-tspmv.hpp"
#include <omp.h>
#include <atomic>

#define THROW_AWAY 10


template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel
      {
	
#pragma omp for schedule(runtime)
	for (VertexType i = 0; i < nVtx; ++i)
	  {
	    Scalar output = 0.;
	    
	    VertexType* beg = adj+xadj[i];
	    VertexType* end = adj+xadj[i+1];
	    Scalar* val2 = val+xadj[i];

	    Scalar ini = in[i];
	    for (auto p = beg; p < end; ++p)
	      {
		VertexType j = *p;
		Scalar res = ini * (*val2);
#pragma omp atomic
		out[j] += res;

		++val2;
	      }
	  }
	
      }    

    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



