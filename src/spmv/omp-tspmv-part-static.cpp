#include "main-tspmv.hpp"
#include <omp.h>

#define THROW_AWAY 10

template<typename VertexType, typename EdgeType, typename Scalar>
void range_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val,
		 VertexType range_begin, VertexType range_end, //included
		 Scalar *in, Scalar* out) {
  for (VertexType i = 0; i < nVtx; ++i)
    {
      Scalar output = 0.;
      
      VertexType* beg = adj+xadj[i];
      VertexType* end = adj+xadj[i+1];

      if (*end < range_begin) continue;
      if (*beg > range_end) continue;

      beg = std::lower_bound(beg, end, range_begin);

      end = std::upper_bound(beg, end, range_end);

      Scalar* val2 = val+(beg-adj);
      Scalar ini = in[i];

      VertexType s = end-beg;

      // for (VertexType p = 0; p< s; ++p) {
      // 	out[beg[p]] += ini * val2[p];
      // }

      for (auto p = beg; p < end; ++p)
      	{
      	  VertexType j = *p;
      	  out[j] += ini * (*val2);
      	  ++val2;
      	}
    }

}


template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  int nbrange;
#pragma omp parallel
  {
#pragma omp master
    nbrange = omp_get_num_threads();
  }
  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

      //init output
#pragma omp parallel for schedule (static)
      for (VertexType i = 0; i < nVtx; ++i)
	out[i] = 0.;

#pragma omp parallel for schedule (static)
      for (int i=0; i<nbrange; ++i) {
	VertexType rb = i*(float)(nVtx/nbrange);
	VertexType re = (int)(i+1*(float)(nVtx/nbrange))-1;
	range_tspmv (nVtx, xadj, adj, val, rb, re, in, out) ;
	//range_tspmv (nVtx, xadj, adj, val, part[i], part[i+1], in, out) ;
      }
    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



