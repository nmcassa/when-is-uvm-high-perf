#include "main-spmv.hpp"

#define THROW_AWAY 10



template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType* xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel for schedule(runtime)
      for (VertexType i = 0; i < nVtx; ++i)
	{
	  Scalar output = 0.;

	  VertexType* beg = adj+xadj[i];
	  VertexType* end = adj+xadj[i+1];
	  Scalar* val2 = val+xadj[i];
	  auto diff = end - beg;
	  auto p = beg;
	  if (diff > 8)
	    {
	      auto aligned = diff - diff%8;
	      auto end_aligned = beg+aligned;
	      for (; p < end_aligned; )
		{
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		  output += in[*p] * (*val2);
		  ++val2;
		  ++p;
		}
	      
	      
	    }

	  for (; p < end; ++p)
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



