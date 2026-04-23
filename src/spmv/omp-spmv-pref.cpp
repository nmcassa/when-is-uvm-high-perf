#include "main-spmv.hpp"
#include <xmmintrin.h>


#define THROW_AWAY 10



template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  EdgeType* pref_p = new EdgeType[nVtx+1];
  VertexType* pref_a = new VertexType[xadj[nVtx]];

  int datasize = sizeof(Scalar);
  int cachelinesize = 64;
    

  pref_p[0] = 0;
  for (VertexType i = 0; i < nVtx; ++i)
    {
      EdgeType cur = pref_p[i];

      VertexType* beg = adj+xadj[i];
      VertexType* end = adj+xadj[i+1];

      auto p = beg;
      VertexType lastblock = *p*datasize/cachelinesize;
	
      for (; p < end; ++p)
	{
	  VertexType block = *p*datasize/cachelinesize;
	  if (block != lastblock)
	    {
	      //emit prefetch
	      pref_a[cur++] = *p;
	      lastblock = block;
	    }
	}
      
      pref_p[i+1] = cur;
    }

  {
    std::stringstream ss;
    ss<<"#prefetch: "<<pref_p[nVtx];
    algo_out=ss.str();
  }

  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel for schedule(runtime)
      for (VertexType i = 0; i < nVtx; ++i)
	{
	  //prefetching
	  {
	    VertexType* beg = pref_a+pref_p[i];
	    VertexType* end = pref_a+pref_p[i+1];
	    for (auto p = beg; p < end; ++p)
	      {
		_mm_prefetch((char*)(in+*p), _MM_HINT_T1);
	      }
	  }

	  Scalar output = 0.;

	  VertexType* beg = adj+xadj[i];
	  VertexType* end = adj+xadj[i+1];
	  Scalar* val2 = val+xadj[i];
	  for (auto p = beg; p < end; ++p)
	    {
	      output += in[*p] * (*val2);
	      ++val2;
	    }
	  
	  out[i] = output;
	}

    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



