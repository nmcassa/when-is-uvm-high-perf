#include "main-spmv.hpp"

#define THROW_AWAY 10



template<typename VertexType, typename EdgeType, typename Scalar>
int main_spmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{
  util::timestamp start(0,0);

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
	
	if (col != lastblock) {
	  lastblock = col;
	  nbblock++;
	  ++nbblockpercolumn[col];
	}	  
      }
      
    }
  
  std::cerr<<"generating prefixsum"<<std::endl;

  VertexType* colbegin = new VertexType[nbColumn+1];
  VertexType* colptr = new VertexType[nbColumn+1];

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
	
	bl_end[colptr[col]] = p-adj;
      }//end for each j

      if (lastcol != -1) {
	++colptr[lastcol];
      }      
    }
  

  

  std::cerr<<"nbblock : "<<nbblock<<" block per row :"<<nbblock/(float)nVtx<<std::endl;


  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();

#pragma omp parallel for schedule(runtime)
      for (VertexType bl = 0; bl < nbblock; ++bl)
	{
	  VertexType i = bl_row[bl];
	  
	  Scalar output = 0.;

	  VertexType* beg = adj+bl_beg[bl];
	  VertexType* end = adj+bl_end[bl];
	  Scalar* val2 = val+bl_beg[bl];
	  for (auto p = beg; p < end; ++p)
	    {
	      output += in[*p] * (*val2);
	      ++val2;
	    }
	  
#pragma omp atomic
	  out[i] += output;
	}

    }
  util::timestamp stop;  

  totaltime += stop - start;

  return 0;
}



