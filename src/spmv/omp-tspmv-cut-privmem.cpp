#include "main-tspmv.hpp"
#include <omp.h>

#define THROW_AWAY 10



template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

  util::timestamp part_start;

  int ColumnBlockSize = 16*1024;

  VertexType nbblock = 0;
  
  VertexType nbColumn = nVtx / ColumnBlockSize;
  if (nVtx % ColumnBlockSize != 0)
    nbColumn++;

  VertexType* nbblockpercolumn =  new VertexType[nbColumn];
  
  for (VertexType i = 0; i<nbColumn; ++i)
    nbblockpercolumn[i] = 0;

  for (VertexType i = 0; i < nVtx; ++i)
    {
      VertexType* beg = adj+xadj[i];
      VertexType* end = adj+xadj[i+1];
      VertexType lastblock = -1;
      for (auto p = beg; p < end; ++p) {
	VertexType j =*p;
	VertexType col = j/ColumnBlockSize;
	
	assert (col >= 0);
	assert (col < nbColumn);

	if (col != lastblock) {
	  lastblock = col;
	  nbblock++;
	  ++nbblockpercolumn[col];
	}	  
      }
      
    }
  
  std::cerr<<"generating prefixsum"<<std::endl;

  VertexType* colbegin = new VertexType[nbColumn+1];
  VertexType* colptr = new VertexType[nbColumn];

  colbegin[0] = 0;
  for (VertexType col = 0; col < nbColumn; ++col) {
    colbegin[col+1] = colbegin[col] + nbblockpercolumn[col];
    colptr[col] = colbegin[col];
  }

  std::cerr<<"generating block decomposition"<<std::endl;

  assert (nbblock > 0);

  VertexType* bl_row = new VertexType[nbblock];
  EdgeType* bl_beg = new EdgeType[nbblock];
  EdgeType* bl_end = new EdgeType[nbblock];
  
  for (VertexType i = 0; i < nVtx; ++i)
    {
      VertexType* beg = adj+xadj[i];
      VertexType* end = adj+xadj[i+1];
      VertexType lastcol = -1;
      for (auto p = beg; p < end; ++p) {
	VertexType j =*p;
	VertexType col = j/ColumnBlockSize;
		
	if (col != lastcol) { //new block
	  if (lastcol != -1) { //this is the first block, there are no blocks to close
	    ++colptr[lastcol];
	  }
	    
	  lastcol = col;
	  bl_beg[colptr[col]] = p-adj;
	  bl_row[colptr[col]] = i;
	}	  
	
	bl_end[colptr[col]] = p-adj+1;
      }//end for each j

      if (lastcol != -1) {
	++colptr[lastcol];
      }      
    }
  
  util::timestamp part_end;
  
 
  std::cout<<part_end - part_start<<" seconds to partition"<<std::endl;

  std::cerr<<"nbblock : "<<nbblock<<" block per row :"<<nbblock/(float)nVtx<<std::endl;

  int nbthreads;
#pragma omp parallel
  {
#pragma omp master
    nbthreads = omp_get_num_threads();
  }

  Scalar** privatememory = new Scalar* [nbthreads];

#pragma omp parallel
  {
    privatememory[omp_get_thread_num()] = new Scalar[ColumnBlockSize];
    memset (privatememory[omp_get_thread_num()], 0, sizeof(Scalar)*ColumnBlockSize);
  }


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();
      

      //      int count = 0;
      
      //#pragma omp parallel  reduction (+ : count)
#pragma omp parallel
      {
	Scalar* myprivatememory = privatememory[omp_get_thread_num()];
	Scalar* myprivateoffseted;
	VertexType lastcolumn = -1;

#pragma omp for schedule(runtime)
	for (VertexType bl = 0; bl < nbblock; ++bl)
	  {
	    VertexType i = bl_row[bl];
	    VertexType* beg = adj+bl_beg[bl];
	    VertexType* end = adj+bl_end[bl];
	    Scalar* val2 = val+bl_beg[bl];
	    Scalar ini = in[i];

	    //commit?
	    if (*beg/ColumnBlockSize != lastcolumn) {
	      if (lastcolumn != -1) {
		//commit
		VertexType begin = (lastcolumn)*ColumnBlockSize;
		VertexType end = (lastcolumn+1)*ColumnBlockSize;
		end = std::min(end, nVtx);
		
		for (VertexType i=begin; i<end; ++i) {
		  if (myprivateoffseted[i] != 0.)
		    {
#pragma omp atomic
		      out[i] += myprivateoffseted[i]; //actual commit
		      myprivateoffseted[i] = 0.; //actual cleanup
		    }
		}
	      }

	      lastcolumn = *beg/ColumnBlockSize;
	      myprivateoffseted = myprivatememory - lastcolumn*ColumnBlockSize;
	    }
	    
	    for (auto p = beg; p < end; ++p)
	      {
		VertexType j = *p;
		myprivateoffseted[j] += ini * (*val2);
		++val2;

		//		++count;
	      }
	    
	  }
      }
      //      std::cout<<count<<" nnz"<<std::endl;
    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



