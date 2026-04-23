#include "main-tspmv.hpp"
#include <omp.h>

#define THROW_AWAY 10


int BLOCKSIZE;

//#define DEBUG
#define max(a,b) (a>b?a:b)
#define min(a,b) (a<b?a:b)
#define blck(a)  ((int)floor((((double)(a)))/BLOCKSIZE))

void transpose(int* sptrs, int* sids, int* tptrs, int* tids, int* indirect, int n) {
  int i;
  int ptr, eptr;

  memset(tptrs, 0, (n+1) * sizeof(int));
  for(i = 0; i < n; i++) {
    eptr = sptrs[i+1];
    for(ptr = sptrs[i]; ptr < eptr; ptr++) {
      tptrs[sids[ptr] + 1]++;
    }
  }

  for(i = 1; i < n; i++) {tptrs[i] += tptrs[i-1];}

  for(i = 0; i < n; i++) {
    eptr = sptrs[i+1];
    for(ptr = sptrs[i]; ptr < eptr; ptr++) {
      indirect[tptrs[sids[ptr]]] = ptr;
      tids[tptrs[sids[ptr]]++] = i;
    }
  }

  for(i = n; i > 0; i--) {tptrs[i] = tptrs[i-1];} tptrs[0] = 0;
}

void colorperm(int* bptrs, int* bids, int* colors, int nocolors, int n, int* lastcolor) {
  int i;
#ifdef DEBUG
  int maxcolorid = -1;
  for(i = 0; i < n; i++) {
    maxcolorid = max(maxcolorid, colors[i]);
  }
  printf("colperm: nocolors is %d n is %d max color id %d\n", nocolors,n, maxcolorid);
#endif
  
  int* bdegs = (int*)malloc(sizeof(int) * (nocolors + 1));
  memset(bdegs, 0, sizeof(int) * (nocolors+1));
  for(i = 0; i < n; i++) bdegs[colors[i]]++;  

  int* count = (int*)malloc(sizeof(int) * n);
  memset(count, 0, sizeof(int) * n);
  for(i = 0; i < nocolors; i++) count[bdegs[i]+1]++;  
  for(i = 1; i <= n; i++) count[i] += count[i-1];

  int* cperm = (int*)malloc(sizeof(int) * nocolors);  
  for(i = 0; i < nocolors; i++) cperm[i] = nocolors - 1 - count[bdegs[i]]++;
  for(i = 0; i < n; i++) {colors[i] = cperm[colors[i]];}
    

  memset(bdegs, 0, sizeof(int) * (nocolors+1));
  for(i = 0; i < n; i++) bdegs[colors[i]+1]++;  

  for(i = 1; i <= nocolors; i++) bdegs[i] += bdegs[i-1];

  memcpy(bptrs, bdegs, sizeof(int) * (nocolors+1)); // ready
  if(bdegs[nocolors] != n) {printf("%d %d they should match\n", bdegs[nocolors], n); exit(1);}
  
  for(i = 0; i <n; i++) {
    int c = colors[i];
    bids[bdegs[c]++] = i;
  } 


  for (int i=0; i< nocolors; ++i)
    {
      printf ("color batch %d has %d vertices\n", i, bptrs[i+1]-bptrs[i] );
    }
  

  free(bdegs);
  free(count);
  free(cperm);
}

template<typename VertexType, typename EdgeType, typename Scalar>
int main_tspmv(VertexType nVtx, EdgeType*xadj, VertexType *adj, Scalar* val, Scalar *in, Scalar* out,
	      int nTry, //algo parameter
	      util::timestamp& totaltime, std::string& algo_out
	      )
{ 

  char* blsstr = getenv("BLOCKSIZE");

  if (blsstr)
    BLOCKSIZE = atoi (blsstr);
  else
    {
      BLOCKSIZE = 64;
      std::cerr<<"BLOCKSIZE undefined. defaulting to : "<<BLOCKSIZE<<std::endl;
    }
 
 /* color the matrix rows */  
  int *tptrs, *tjs, *indirect, *colors, *ptrs = xadj, *js = adj, *bptrs, *bids;
  int m = nVtx, nz = xadj[nVtx], nocolors, p2, tj, i, j, p;  	           

  tptrs = (int *) malloc((m+1) * sizeof(int));
  tjs = (int *) malloc(nz * sizeof(int));
  indirect = (int *) malloc(nz * sizeof(int));
  transpose(ptrs,js,tptrs,tjs,indirect,m); /* indirect will not be useless but still we do it */


  int b, blocktj, noblocks = ceil((double)m / BLOCKSIZE); 
  nocolors = 0;
  colors = (int *) malloc(noblocks * sizeof(int));

  int* mark = (int *) malloc(m * sizeof(int));
  for(i = 0; i < m; i++) {mark[i] = -1;}


  for(i = 0; i < noblocks; i++) {indirect[i] = -1; colors[i] = -1;}
  for(b = 0; b < noblocks; b++) {
    for(i = b*BLOCKSIZE; i < min(m, (b+1)*BLOCKSIZE); i++) { /* for all rows i in the current block*/           
      for(p = ptrs[i]; p < ptrs[i+1]; p++) { /* for all neighbours of row i */	
	j = js[p];
	if(mark[j] != b) {
	  mark[j] = b;
	  for(p2 = tptrs[j]; p2 < tptrs[j+1]; p2++) { /* for all neighbours of col j */
	    tj = tjs[p2]; blocktj = blck(tj); /* tj is the block id that b has a conflict at clumn j */
	    if(blocktj < b) { /* only checks the block indices of column j smaller than b since the others are not colored */
	      indirect[colors[blocktj]] = b; /* block b shares a column index with block blocktj */	
	    } else {
	      break; /* ASSUME: col row ids are sorted. transpose(...) handles that 
			regardless of the input so continuing with column j is redundant*/
	    }
	  }
	}
      }
      if(i % 50000 == 0) printf("%d\n", i);                                                                                                                                                                                                
    }
    
    for(j = 0; j < noblocks; j++) {
      if(indirect[j] != b) {
	colors[b] = j; 	
	break;
      }
    }   
  } /* coloring finished */

  for(i = 0; i < noblocks; i++) indirect[i] = 0;
  for(i = 0; i < noblocks; i++) indirect[colors[i]] = 1;
  nocolors = 0;
  for(i = 0; i < noblocks; i++) nocolors += (indirect[i] == 1);
  printf("Colors generated... There are %d of them\n", nocolors); fflush(0);  

#ifdef DEBUG
  printf("Colors generated... There are %d of them\n", nocolors); fflush(0);  
  for(i = 0; i < noblocks; i++) {if(colors[i] >= nocolors) printf("color %d for vertex %d is not smaller than number of colors\n", colors[i], i);}
  
  //conflict detection                                                                                                                                                                                                                     
  for(i = 0; i < noblocks; i++) {indirect[i] = -1;}
  for(i = 0; i < m; i++) {
    int pblock = -1;
    for(p = tptrs[i]; p < tptrs[i+1]; p++) {
      tj = tjs[p]; blocktj = blck(tj); 

      if(p == tptrs[i] || pblock != blocktj) {
	pblock = blocktj;

	int c = colors[blocktj];
	if(indirect[c] == i) {
	  printf("there is a conflict: column %d\n", i);
	  for(p = tptrs[i]; p < tptrs[i+1]; p++) {
	    int blc = blck(tjs[p]);
	    printf("(%d-%d-%d) ", tjs[p], blc, colors[blc]);  fflush(0);
	  }
	  printf("\n");  fflush(0);
	  exit(1);
	}
	indirect[c] = i;
      }
    }
  }
#endif
  
  bptrs = (int *) malloc((nocolors+1) * sizeof(int));
  bids = (int *) malloc(noblocks * sizeof(int));
  int lastcolor = 0;
  
  colorperm(bptrs, bids, colors, nocolors, noblocks, &lastcolor);    

  
#ifdef DEBUG
  int* test = (int*)malloc(sizeof(int) * noblocks);
  memset(test, 0, sizeof(int) * noblocks);
  
  for(i = 0; i < noblocks; i++) {
    if(bids[i] < 0 || bids[i] > noblocks-1) {
      printf("bids[i] = %d\n", bids[i]);  fflush(0);
      exit(1);
    }
    test[bids[i]]++;
  }

  for(i = 0; i < noblocks; i++) {    
    if(test[i] != 1){
      printf("bids array is wrong %d is %d\n", i, bids[i]);  fflush(0);
      exit(1);
    }
  }  

  fflush(0);
  free(test);

#endif

  free(tptrs); 
  free(tjs);
  free(indirect);
  
  util::timestamp start(0,0);

  for (int TRY=0; TRY<THROW_AWAY+nTry; ++TRY)
    {
      if (TRY == THROW_AWAY)
	start = util::timestamp();
      
      for (int col = 0; col < nocolors; ++col) {
#pragma omp parallel for schedule(dynamic,1)
	for (VertexType xi = bptrs[col]; xi < bptrs[col+1]; ++xi)
	  {
	    VertexType bid = bids[xi];
	    VertexType end = min(BLOCKSIZE*(bid+1),m);
	    for(VertexType i = BLOCKSIZE*bid; i < end; i++) {
	      Scalar output = 0.;
	      
	      VertexType* beg = adj+xadj[i];
	      VertexType* end = adj+xadj[i+1];
	      Scalar* val2 = val+xadj[i];
	      Scalar ini = in[i];
	      for (auto p = beg; p < end; ++p)
		{
		  VertexType j = *p;
		  out[j] += ini * (*val2);
		  ++val2;
		}
	    }      
	  }
      }
    }
  util::timestamp stop;  
  
  totaltime += stop - start;
  
  //freemem
  free(colors);    
  free(bptrs);
  free(bids);
  return 0;
}



