#include "main-tspmv.hpp"
#include <omp.h>
#include <immintrin.h>
#include <unordered_map>

#define THROW_AWAY 10

template<typename T>
struct idhash{
  const T& operator() (const T& t) const{return t;}
};


template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  int nbthreads;
#pragma omp parallel
  {
#pragma omp master
    nbthreads = omp_get_num_threads();
  }

  //  Scalar** privatememory = new Scalar*[nbthreads];
  std::unordered_map<VertexType,Scalar,idhash<int>> * privatememory = new std::unordered_map<VertexType,Scalar,idhash<int>>[nbthreads];
  
#pragma omp parallel
  {
    int tid = omp_get_thread_num();
    //    privatememory[tid] = new Scalar[nVtx];
    //privatememory[tid] = (Scalar*) _mm_malloc(nVtx*sizeof(Scalar), 64);
    
    // Scalar* myprivatememory = privatememory[tid];
    // for (VertexType i=0; i<nVtx; ++i)
    //   myprivatememory[i] = 0.;
  }

  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel
      {
	int tid = omp_get_thread_num();
	//	Scalar* myprivatememory = privatememory[tid];
	std::unordered_map<VertexType,Scalar,idhash<int>>&  myprivatememory = privatememory[tid];

	myprivatememory.clear();

	//flush private memory
	//	for (VertexType i=0; i<nVtx; ++i)
	//myprivatememory[i] = 0.;
	//memset(myprivatememory, 0, sizeof(Scalar)*nVtx);
	
#pragma omp for schedule (runtime)
	for (VertexType i = 0; i < nVtx; ++i)
	  {
	    VertexType* beg = adj+xadj[i];
	    VertexType* end = adj+xadj[i+1];
	    Scalar* val2 = val+xadj[i];
	    Scalar ini = in[i];
	    for (auto p = beg; p < end; ++p)
	      {
		VertexType j = *p;
		myprivatememory[j] += ini * (*val2);
		++val2;
	      }
	  }
	
	//fill output
 #pragma omp for schedule (static)
 	for (VertexType i = 0; i < nVtx; ++i) {
 	  Scalar outv = 0.;
	  
 	  for (int t=0; t<nbthreads;++t)
	    {
	      auto it = privatememory[t].find(i);
	      if (it != privatememory[t].end())
		outv += it->second;
	    }
	  
 	  out[i] = outv;
 	} 
      }    

    }
  util::timestamp stop;  

  totaltime += stop - start;

  //freemem

  return 0;
}



