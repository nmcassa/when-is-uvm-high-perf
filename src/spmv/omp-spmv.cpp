#include "main-spmv.hpp"

#define THROW_AWAY 10
#include "Padded2DArray.hpp"
#include <omp.h>
#include "memutils.hpp"

//#define SHOWLOADBALANCE
#include "logged_array.hpp"

//#define LOG

template <typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType* xadj_, VertexType *adj_, Scalar* val_, Scalar *in_, Scalar* out_,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  bool coldcache = true;
  
  util::timestamp start(0,0);

#ifdef LOG
  LoggedArray<EdgeType, logtextomp> xadj (xadj_, (nVtx+1)*sizeof(xadj_[0]), "xadj");
  LoggedArray<VertexType, logtextomp> adj (adj_, xadj_[nVtx]*sizeof(adj_[0]), "adj");
  LoggedArray<Scalar, logtextomp> val (val_, nVtx*sizeof(val_[0]), "val");

  LoggedArray<Scalar, logtextomp> in (in_, nVtx*sizeof(in_[0]), "in");
  LoggedArray<Scalar, logtextomp> out (out_, nVtx*sizeof(out_[0]), "out");

#else
  EdgeType* xadj = xadj_;
  VertexType *adj = adj_;
  Scalar* val = val_;
  Scalar* in = in_;
  Scalar* out = out_;
#endif
  
#ifdef SHOWLOADBALANCE
  Padded1DArray<int> count (244);

  for (int i=0; i<244; ++i)
    count[i] = 0;
#endif


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY >= THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel
      {

#ifdef SHOWLOADBALANCE
	int tid = omp_get_thread_num();
	count[tid] = 0;
#endif

#pragma omp  for schedule(runtime)
	for (VertexType i = 0; i < nVtx; ++i)
	  {
#ifdef SHOWLOADBALANCE
	    ++count[tid];
#endif

	    Scalar output = 0.;

	    EdgeType beg = xadj[i];
	    EdgeType end = xadj[i+1];

	    for (EdgeType p = beg; p < end; ++p)
	      {
#ifdef PREFETCH_DISTANCE
		_mm_prefetch((char*)(adj+p)+PREFETCH_DISTANCE, _MM_HINT_NTA);
		_mm_prefetch((char*)(val+p)+PREFETCH_DISTANCE, _MM_HINT_NTA);
#endif

		output += in[adj[p]] * val[p];
	      }


	    // VertexType* beg = adj+xadj[i];
	    // VertexType* end = adj+xadj[i+1];
	    // Scalar* val2 = val+xadj[i];
	    // for (auto p = beg; p < end; ++p)
	    //   {
	    //     output += in[*p] * (*val2);
	    //     ++val2;
	    //   }
	  
	    out[i] = output;
	  }
	
	_mm_lfence();
	_mm_mfence();
      }

      if (TRY >= THROW_AWAY)
	{
	  util::timestamp stop;  
	  totaltime += stop - start;
	}
      
#ifndef LOG
      if (coldcache) {
#pragma omp parallel
	{
	  evict_array_from_cache(adj, xadj[nVtx]*sizeof(*adj));
	  evict_array_from_cache(xadj, (nVtx+1)*sizeof(*xadj));
	  evict_array_from_cache(val, xadj[nVtx]*sizeof(*val));
	  evict_array_from_cache(in, nVtx*sizeof(*in));
	  evict_array_from_cache(out, nVtx*sizeof(*out));

#pragma omp barrier
	}
      }
#endif

    }

#ifdef SHOWLOADBALANCE
  std::cout<<"load balance"<<std::endl;
  for (int i=0; i< 244; ++i)
    std::cout<<count[i]<<std::endl;
#endif

  return 0;
}

  
  
