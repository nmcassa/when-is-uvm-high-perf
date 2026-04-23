/*
  File  : graph.c
  Author: UVC
  Date  : Oct 1st, 2004
  Descr : chaco/metis format graph reader
*/

#include "ulib.h"
#include <string>
#include <sstream>
#include <assert.h>
#include <iostream>
#include <algorithm>
#include <fstream>
#include <map>
#include <sstream>
#include <vector>

#define MAXLINE 128*(1024*1024)

/* reads the MeTiS format graph (Cannot handle multiple vertex weights!)
   file pointed by filename into pxadj, padjncy, padjncyw, ppvw:
   if you don't want edge weights pass NULL as padjncyw param 
   same for vertex weights pass NULL as ppvw 
   note that *pxadj, *padjncy, *padjncyw is allocated by by this function and must be freed by user of 
   this function*/

template <typename VtxType, typename EdgeIndex, typename WeightType>
void ReadGraphFromFile(FILE *fpin, VtxType *numofvertex, EdgeIndex **pxadj, VtxType **padjncy, WeightType **padjncyw, WeightType **ppvw)
{
  VtxType *adjncy,  nvtxs, fmt, readew, readvw, edge, i, ncon;
  EdgeIndex k, nedges, *xadj;
  WeightType *adjncyw=NULL, *pvw=NULL;
  char *line;
    
  line = (char *)malloc(((size_t)sizeof(char))*(MAXLINE+1));
    
    do {
        fgets(line, MAXLINE, fpin);
    } while (line[0] == '%' && !feof(fpin));
    
    if (feof(fpin)) 
        errexit("empty graph!!!");
    
    fmt = 0;
    //sscanf(line, "%d %d %d %d", &nvtxs, &nedges, &fmt, &ncon);
    {
      std::string s = line;
      std::stringstream ss (s);
      ss>>nvtxs>>nedges>>fmt>>ncon;
    }
    *numofvertex = nvtxs;
    
    readew = (fmt%10 > 0);
    readvw = ((fmt/10)%10 > 0);
    if (fmt >= 100) 
        errexit("invalid format");
    
    nedges *=2;
    
    xadj = *pxadj = new EdgeIndex[nvtxs+2];
    adjncy = *padjncy = new VtxType[nedges];
    if (padjncyw)
      {
	adjncyw = *padjncyw = new WeightType [nedges];
      }
    if (ppvw)
      {
	pvw = *ppvw = new WeightType[nvtxs+1];
      }
    
    for (xadj[0]=0, k=0, i=0; i<nvtxs; i++) {
        char *oldstr=line, *newstr=NULL;
        int  ewgt=1, vw=1;
        
        do {
            fgets(line, MAXLINE, fpin);
	} while (line[0] == '%' && !feof(fpin));
        
        if (strlen(line) >= MAXLINE-5) 
            errexit("\nBuffer for fgets not big enough!\n");
        
        if (readvw) {
            vw = (VtxType)strtol(oldstr, &newstr, 10);
            oldstr = newstr;
	}
        
        if (ppvw)
            pvw[i] = vw;	
        
        for (;;) {
            edge = (VtxType)strtol(oldstr, &newstr, 10) -1;
            oldstr = newstr;
            
            if (readew) {
                ewgt = (WeightType)strtol(oldstr, &newstr, 10);
                oldstr = newstr;
	    }
            
            if (edge < 0)
                break;

	    //            if (edge==i)
	    //	      errexit("Self loop in the graph for vertex %d\n", i);
            adjncy[k] = edge;
            if (padjncyw)
                adjncyw[k] = ewgt;
            k++;
	} 
        xadj[i+1] = k;
    }
    
    if (k != nedges) {
      std::cerr<<"found "<<k<<" edges. Expected "<<nedges<<std::endl;
      exit(-1);
    }

    free(line);
}


/**
 * builds a graph out of an edgelist file.
 * all lines starting with # or % are discarded.
 * all other lines should be in the format <from> <to> where from and to can be arbitrary words (no space).
 * The algorithm is one pass (meaning that it uses more memory than necessary).
 **/
template <typename VtxType, typename EdgeIndex>
void ReadEdgeList(const std::string filename, VtxType *numofvertex, EdgeIndex **pxadj, VtxType **padjncy, std::map<std::string, VtxType>& nametoid, bool symmetrize) {
  
  std::ifstream in (filename);
  
  std::vector< std::vector< VtxType> > dynadjlist;

  VtxType nbID = 0;

  assert (nametoid.empty());

  while (in) {
    //reading line
    std::string line;
    std::getline(in, line);
    if (!in) continue;

    if (line[0] == '#' || line[0] == '%') continue;
	
    std::stringstream ss;
    ss.str(line);
    std::string from, to;
    
    ss>>from>>to;
    if (!ss) continue;

    //getting IDs
    VtxType fromID, toID;
    {
      auto fit = nametoid.find(from);
      if (fit != nametoid.end())
	fromID = fit->second;
      else {
	fromID = nbID;
	nbID++;
	nametoid[from] = fromID;
      }

      auto tit = nametoid.find(to);
      if (tit != nametoid.end())
	toID = tit->second;
      else {
	toID = nbID;
	nbID++;
	nametoid[to] = toID;
      }

    }

    //insert edge
    VtxType m = std::max(fromID, toID);
    assert (m >= 0);
    if (dynadjlist.size() <= m) 
      dynadjlist.resize(m+1);
    
    dynadjlist[fromID].push_back(toID);
    if (symmetrize)
      dynadjlist[toID].push_back(fromID);
  }    

  //sort and retain unique id
#pragma omp parallel for schedule(dynamic,16)
  for (VtxType i = 0; i< nbID; ++i) {
    std::sort (dynadjlist[i].begin(), dynadjlist[i].end());
    std::unique (dynadjlist[i].begin(), dynadjlist[i].end());
  }

  //generate CRS
  EdgeIndex nbedge = 0;
  for (VtxType i = 0; i< nbID; ++i) 
    nbedge += dynadjlist[i].size();
    
  *numofvertex = nbID;
  *pxadj = new EdgeIndex[nbID+1];
  *padjncy = new VtxType [nbedge];
  
  (*pxadj)[0] = 0;
  
  for (VtxType i = 0; i< nbID; ++i) {
    (*pxadj)[i+1] = (*pxadj)[i] + dynadjlist[i].size();

    std::copy (dynadjlist[i].begin(), dynadjlist[i].end(), (*padjncy)+(*pxadj)[i]);
  }
  
}



#include "mmio.h"


//create a crs graph representation from I,J,V representation
template<typename VertexType, typename EdgeType, typename Scalar, typename VtxArray, typename ScalArray>
void createCRS(VtxArray& I, VtxArray& J, ScalArray V, VertexType m, VertexType n, EdgeType nz, EdgeType* ptrs,  VertexType* js, Scalar* vals) {  
  VertexType i, j;
  EdgeType *idegs; //It should be VertexType but we will use memory copy between idegs and ptrs
  Scalar *vals_dense;

  idegs = new EdgeType[m+1];
  memset(idegs, 0, sizeof(EdgeType) * (m+1));

  if (vals != NULL)
    vals_dense = new Scalar[n];

  for (i = 0; i < nz; i++)
    idegs[I[i] + 1]++;       
  
  for(i = 0; i < m; i++)
    idegs[i+1] += idegs[i];
  
  memcpy(ptrs, idegs, sizeof(EdgeType) * (m+1));

  for (i = 0; i < nz; ++i ) {
      js[idegs[I[i]]] = J[i];

      if (vals != NULL)
	vals[idegs[I[i]]] = V[i];
      idegs[I[i]]++;
  }

  for(i = 0; i < m; i++) {
    if (vals != NULL)
      for(j = ptrs[i]; j < ptrs[i+1]; j++) 
	vals_dense[js[j]] = vals[j];

    std::sort(js + ptrs[i], js + ptrs[i+1] );
    
    if (vals != NULL)
      for(j = ptrs[i]; j < ptrs[i+1]; j++)
	vals[j] = vals_dense[js[j]];
  }


#ifdef DEBUG
  float avdeg = (1.0f * nz) / m;
  int maxdeg = 0;
  int mindeg = m;
  int zerodeg = 0;
  float sum = 0;
  int deg;

  for(i = 0; i < m; i++) {
    deg =  ptrs[i+1] - ptrs[i];
    if(deg == 0) zerodeg++;   
    maxdeg = max(maxdeg, deg);
    mindeg = min(mindeg, deg);;
    sum += (deg - avdeg) * (deg - avdeg);
  }
  printf("#0 deg: %d\n", zerodeg);
  printf("Deg. min %d\n", mindeg);
  printf("Deg. max %d\n", maxdeg);
  printf("Deg. avg %f\n", avdeg);
  printf("Deg. variance %f\n", sqrt(sum/m));
#endif

  if (vals != NULL)
    delete[](vals_dense);

  delete[] idegs;
}


template<typename VertexType, typename EdgeType, typename Scalar>
int ReadGraph_mtx(char* filename, 
		  VertexType* nRow, VertexType* nCol,
		  EdgeType** ptrs, VertexType** js, Scalar** vals)
{

  VertexType* I;
  VertexType* J;
  Scalar* V;

  EdgeType nz;
  VertexType m;


  FILE* f;

  EdgeType i;

  MM_typecode matcode;

  int ret_code;
  VertexType n;

  EdgeType tnz;

  if((f = fopen(filename,"r")) == NULL) {
    printf("Invalid file\n");
    return 0;
  }

  std::cerr<<"file opened"<<std::endl;

  if (mm_read_banner(f, &matcode) != 0) {
    printf("Could not process Matrix Market banner.\n");
    exit(1);
  }

  /*  This is how one can screen matrix types if their application */
  /*  only supports a subset of the Matrix Market data types.      */

  if (mm_is_complex(matcode) && mm_is_matrix(matcode) && 
      mm_is_sparse(matcode) ) {
    printf("Sorry, this application does not support ");
    printf("Market Market type: [%s]\n", mm_typecode_to_str(matcode));
    exit(1);
  }
  /* find out size of sparse matrix .... */

  if ((ret_code = mm_read_mtx_crd_size(f, &m, &n, &tnz)) !=0)
    exit(1);

  /* memory for matrices */
  I = (VertexType *) malloc(2*tnz * sizeof(VertexType));
  J = (VertexType *) malloc(2*tnz * sizeof(VertexType));
  V = (Scalar *) malloc(2*tnz * sizeof(Scalar));
  /*  NOTE: when reading in doubles, ANSI C requires the use of the "l"  */
  /*   specifier as in "%lg", "%lf", "%le", otherwise errors will occur  */
  /*   (ANSI C X3.159-1989, Sec. 4.9.6.2, p. 136 lines 13-15)            */
  nz = 0;
  //  printf("tnz is %d\n", tnz);

  assert (sizeof(VertexType) == sizeof(int)); //the file operations assume that

  for (i=0; i < tnz; i++) {
    if (mm_is_pattern(matcode)) {
      fscanf(f, "%d %d\n", &I[nz], &J[nz]);
      V[nz] = 1;
    }
    else //assume general
      {

	  double v;
	  fscanf(f, "%d %d %lf\n", &I[nz], &J[nz], &v);
	  V[nz] = v; //note this work in float too thanks to templating.

      }
                

    if(V[nz] == 0) {
      //printf("%d %d equals to 0\n", I[nz], J[nz]);
    } else {
      I[nz]--;  /* adjust from 1-based to 0-based */
      J[nz]--;

      if (I[nz] <0 || I[nz] > m) {
	std::cerr<<"read error"<<std::endl; return -1;
      }
      if (J[nz] <0 || J[nz] > n) {
	std::cerr<<"read error"<<std::endl; return -1;
      }

      if (mm_is_symmetric(matcode) && I[nz] != J[nz])
	{
	  nz++;
	  I[nz] = J[nz-1];
	  J[nz] = I[nz-1];
	  V[nz] = V[nz-1];

	}
      nz++;      
    }
  }
  if (f !=stdin) fclose(f);


#ifdef DEBUG
  /************************/
  /* now write out matrix */
  /************************/  
  mm_write_banner(stdout, matcode);
  mm_write_mtx_crd_size(stdout, m, n, nz);
#endif


  *ptrs = new EdgeType[m+1];
  *js = new VertexType[nz];

  if (vals != NULL)
    *vals = new Scalar[nz];


  std::cerr<<"file read. converting to CRS"<<std::endl;

  if (vals != NULL)
    createCRS(I, J, V, m, n, nz, *ptrs, *js, *vals);
  else
    createCRS(I, J, V, m, n, nz, *ptrs, *js, (Scalar*)NULL);

  free(I);
  free(J);
  free(V);

  *nRow = m;
  *nCol = n;
  return 0;
}


typedef struct pair {
  long long f;
  long long s;
} Pair;

int pcmp(const void *v1, const void *v2){
  long long diff = (((Pair *)v1)->f - ((Pair *)v2)->f);
  if (diff != 0)
    return diff;
  else
    return (((Pair *)v1)->s - ((Pair *)v2)->s);
}
//this reads file in a format which is similar to matrix market, but which is different.
//The vertices are relabelled to map tot the [0:*numofvertex] range
template <typename VtxType, typename EdgeType, typename WeightType>
void ReadGraphFromMMFile_withrelabelling(const char* filename, VtxType *numofvertex, EdgeType **pxadj, VtxType **padjncy, WeightType **padjncyw, WeightType **ppvw, bool do_mapping, long** reverse_map) {
  
  Pair *coords, *new_coords;
  int m, n, itemp, jtemp;
  long long nnz, tnnz, i, j, onnz;;
  int *xadj, *adj;

  int maxLineLength = 1000000;
  char line[maxLineLength];
  int num_items_read;

  assert (sizeof(VtxType) == sizeof(int));
  assert (sizeof(EdgeType) == sizeof(int));

  FILE *matfp = ufopen(filename, "r", "main: fpin");

  /* set return null parameter values, in case we exit with errors */
  m = nnz = 0;

  /* now continue scanning until you reach the end-of-comments */
  do {
    fgets(line, 1000000, matfp);
  } while (line[0] == '%');

  /* line[] is either blank or has M,N, nz */
  if (sscanf(line, "%d %d %lld", &m, &n, &nnz) != 3) {
    do {
      num_items_read = fscanf(matfp, "%d %d %lld", &m, &n, &nnz);
      if (num_items_read == EOF)
	return;
    }
    while (num_items_read != 3);
  }

  if (reverse_map)
    *reverse_map = (long*) malloc (sizeof(long) * n);
  //      printf("matrix banner is read %d - %d, %lld nnz\n", m, n, nnz);                                                              
  coords = (Pair*) malloc(sizeof(Pair) * 2 * nnz);

  tnnz = 0;
  for(i = 0; i < nnz; i++) {
    fscanf(matfp, "%d %d\n", &itemp, &jtemp);

    if(itemp != jtemp) {
      coords[tnnz].f = itemp - 1;
      coords[tnnz++].s = jtemp - 1;
      coords[tnnz].f = jtemp - 1;
      coords[tnnz++].s = itemp - 1;
    }
  }
  qsort(coords, tnnz, sizeof(Pair), pcmp);
  
  onnz = 1;
  for(i = 1; i < tnnz; i++) {
    if(coords[i].f != coords[onnz-1].f || coords[i].s != coords[onnz-1].s) {
      coords[onnz].f = coords[i].f;
      coords[onnz++].s = coords[i].s;
    }
  }
  
  *numofvertex = n;
  xadj = *pxadj = (int*) malloc((n+1) * sizeof(int));
  adj = *padjncy = (int*) malloc(onnz * sizeof(int));
  if (padjncyw)
    *padjncyw = (WeightType*) malloc (nnz * sizeof(WeightType));
  if (ppvw)
    *ppvw = (WeightType*) malloc ((n+1)*sizeof(WeightType));
  
  if (do_mapping) {
    std::map<long, int> reed;
    std::map<long, int>::iterator reed_it;
    new_coords = (Pair*) malloc(sizeof(Pair) * 2 * nnz);
    long vno = 0;
    // map the ids                                                                                                               
    for(i = 0; i < onnz; i++) {
      long temp = coords[i].f;
      reed_it = reed.find(temp);
      if (reed_it == reed.end()) {
	reed.insert (std::make_pair (temp, vno));
	if (reverse_map)
	  (*reverse_map)[vno] = temp;
	new_coords[i].f = vno++;
      }
      else
	new_coords[i].f = reed_it->second;
      
      temp = coords[i].s;
      reed_it = reed.find(temp);
      if (reed_it == reed.end()) {
	reed.insert (std::make_pair (temp, vno));
	if (reverse_map)
	  (*reverse_map)[vno] = temp;
	new_coords[i].s = vno++;
      }
      else
	new_coords[i].s = reed_it->second;
    }
  }
  std::vector<std::vector<int> > entire_graph;
  entire_graph.resize(n);
  for(i = 0; i < onnz; i++) {
    if (do_mapping)
      entire_graph[new_coords[i].f].push_back(new_coords[i].s);
    else
      entire_graph[coords[i].f].push_back(coords[i].s);
  }
  xadj[0] = 0;
  j = 0;
  for(i = 1; i < n+1; i++) {
    xadj[i] = xadj[i-1] + entire_graph[i-1].size();
    for (unsigned int k = 0; k < entire_graph[i-1].size(); k++) {
      adj[j++] = entire_graph[i-1][k];
    }
  }
  
  //      printf("matrix is read %d - %d, %lld onnz\n", m, n, onnz);                                                                   
  free(coords);
  
  return;
}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void ReadGraph_chaco(char *filename, VtxType *numofvertex_r, VtxType *numofvertex_c, EdgeIndex **pxadj, VtxType **padjncy, WeightType **padjncyw, WeightType **ppvw)
{
    FILE *fpin = ufopen(filename, "r", "main: fpin");
    
    ReadGraphFromFile(fpin, numofvertex_r, pxadj, padjncy, padjncyw, ppvw);
    *numofvertex_c = *numofvertex_r; //in chaco format these are graphs, so they must be square.
    ufclose(fpin);
}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void GraphFree(EdgeIndex *xadj, VtxType *adjncy, WeightType* adjncyw = NULL)
{
  delete[] xadj;
  delete[] adjncy;
  if (adjncyw)
    delete[] adjncyw;
}

///returns 0 if correct, -1 otherwise
static int really_read(std::istream& is, char* buf, size_t global_size) {
  char* temp2 = buf;
  while (global_size != 0)
    {
      assert (global_size > 0);
      is.read(temp2, global_size);
      size_t s = is.gcount();
      if (!is)
	return -1;
      assert (s >0);
      assert (s <= global_size);
      
      global_size -= s;
      temp2 += s;
    }
  return 0;
}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void ReadBinary(char *filename, VtxType *numofvertex_r, VtxType *numofvertex_c, EdgeIndex **pxadj, VtxType **padj, WeightType **padjw, WeightType **ppvw) {

  if (ppvw != NULL) {std::cerr<<"vertex weight is unsupported"<<std::endl; return;}
  std::ifstream in (filename);
  if (!in.is_open()) {std::cerr<<"can not open file:"<<filename<<std::endl; return;}

  int vtxsize; //in bytes
  int edgesize; //in bytes
  int weightsize; //in bytes
  //reading header
  in.read((char*) &vtxsize, sizeof(int));
  in.read((char*) &edgesize, sizeof(int));
  in.read((char*) &weightsize, sizeof(int));

  if (!in) {std::cerr<<"IOError"<<std::endl; return;}
  if (vtxsize != sizeof(VtxType)){ 
    std::cerr<<"Incompatible VertexSize."<<std::endl;
    return;
  }
  if (edgesize != sizeof(EdgeIndex)){ 
    std::cerr<<"Incompatible EdgeSize."<<std::endl;
    return;
  }
  if (weightsize != sizeof(WeightType) && padjw){ 
    std::cerr<<"Incompatible WeightType."<<std::endl;
    return;
  }
  //reading should be fine from now on.
  in.read((char*)numofvertex_r, sizeof(VtxType));
  in.read((char*)numofvertex_c, sizeof(VtxType));
  EdgeIndex nnz;
  in.read((char*)&nnz, sizeof(EdgeIndex));
  if (*numofvertex_c <=0 || *numofvertex_r <=0 || nnz <= 0) {
    std::cerr<<"graph makes no sense"<<std::endl;
    return;
  }
  *pxadj = new EdgeIndex[*numofvertex_r+1];
  *padj = new VtxType[nnz];
  if (padjw) {
    *padjw = new WeightType[nnz];
  }
  int err = really_read(in, (char*)*pxadj, sizeof(EdgeIndex)*(*numofvertex_r+1));
  err += really_read(in, (char*)*padj, sizeof(VtxType)*(nnz));
  if (padjw)
    err += really_read(in, (char*)*padjw, sizeof(WeightType)*(nnz));
  if (!in || err != 0) {
    std::cerr<<"IOError"<<std::endl;
  }

}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void WriteBinary(const char *filename, VtxType numofvertex_r, VtxType numofvertex_c,
		 EdgeIndex *xadj, VtxType *adj, WeightType *adjw) {
  std::ofstream out(filename);
  if (!out) {
    std::cerr<<"can not open output file"<<std::endl;
    return;
  }
  int vs = sizeof(VtxType);
  int es = sizeof(EdgeIndex);
  int ws = sizeof(WeightType);
  out.write((char*) &vs, sizeof(int));
  out.write((char*) &es, sizeof(int));
  out.write((char*) &ws, sizeof(int));

  out.write((char*)&numofvertex_r, sizeof(VtxType)); 
  out.write((char*)&numofvertex_c, sizeof(VtxType));
  out.write((char*)(xadj+numofvertex_r), sizeof(EdgeIndex));

  out.write((char*)xadj, (1+numofvertex_r)*sizeof(EdgeIndex));
  out.write((char*)adj, (xadj[numofvertex_r])*sizeof(VtxType));
  out.write((char*)adjw, (xadj[numofvertex_r])*sizeof(WeightType));
}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void WriteChaco(const char *filename, VtxType numofvertex_r, VtxType numofvertex_c,
		EdgeIndex *xadj, VtxType *adj, WeightType *adjw) {
  std::ofstream out(filename);
  if (!out) {
    std::cerr<<"can not open output file"<<std::endl;
    return;
  }
  out<<numofvertex_r<<" "<<xadj[numofvertex_r]/2<<" "<<1<<"\n";
  for (VtxType u = 0; u< numofvertex_r; ++u) {
    for (EdgeIndex p = xadj[u]; p<xadj[u+1]; ++p) {
      out<<adj[p]+1<<" ";
      if (adjw)
	out<<adjw[p]<<" ";
      else
	out<<(WeightType)1<<" ";
    }
    out<<"\n";
  }
  out.flush();
}

template <typename VtxType, typename EdgeIndex, typename WeightType>
void WriteGraph(const char *filename, VtxType numofvertex_r, VtxType numofvertex_c,
		EdgeIndex *xadj, VtxType *adj, WeightType *adjw) {
  if (strlen(filename) <= 4) {std::cerr<<"unknown filetype"<<std::endl; return;}
  if (strcmp((filename+strlen(filename)-4), ".bin") == 0)
    {
      WriteBinary<VtxType, EdgeIndex, WeightType> (filename, numofvertex_r, numofvertex_c, xadj, adj, adjw);
    }
  else
    {
      std::cerr<<"assuming chaco"<<std::endl;
      WriteChaco<VtxType, EdgeIndex, WeightType> (filename, numofvertex_r, numofvertex_c, xadj, adj, adjw);
    }

}

///call GraphFree to free memory
template <typename VtxType, typename EdgeIndex, typename WeightType>
void ReadGraph(char *filename, VtxType *numofvertex_r, VtxType *numofvertex_c,
	       EdgeIndex **pxadj, VtxType **padjncy, WeightType **padjncyw, WeightType **ppvw)
{
  if (strlen(filename) <= 4) {std::cerr<<"unknown filetype"<<std::endl; return;}
  if (strcmp((filename+strlen(filename)-4), ".mtx") == 0)
    {
      std::cerr<<".mtx file"<<std::endl;

      if constexpr (std::is_same_v<EdgeIndex, int64_t>) {
	throw "unsupported"; //The mtx parser is written with C format string and breaks
      }
      else {
      
	ReadGraph_mtx<VtxType,EdgeIndex,WeightType> (filename, numofvertex_r, numofvertex_c, pxadj, padjncy, padjncyw);
	if (ppvw != NULL)
	  std::cerr<<"vertex weight is unsupported"<<std::endl;
      }
    }
  else
  if (strcmp((filename+strlen(filename)-4), ".bin") == 0)
    {
      ReadBinary<VtxType,EdgeIndex,WeightType>(filename,numofvertex_r, numofvertex_c, pxadj, padjncy,padjncyw, ppvw);
    }
  else
  if (strcmp((filename+strlen(filename)-4), ".txt") == 0) 
    {
      //assuming fake matrix market file
      //      ReadGraphFromMMFile_withrelabelling<VtxType,EdgeIndex,WeightType> (filename, numofvertex_r, pxadj, padjncy, padjncyw, ppvw, true, NULL);
      std::map<std::string, VtxType> mapping;
      ReadEdgeList<VtxType,EdgeIndex> (filename, numofvertex_r, pxadj, padjncy, mapping, true);
      *numofvertex_c = *numofvertex_r;
    }
  else
    {
      std::cerr<<".graph file"<<std::endl;
      ReadGraph_chaco<VtxType,EdgeIndex,WeightType>(filename, numofvertex_r, numofvertex_c, pxadj, padjncy, padjncyw, ppvw);
      auto nEdge = (*pxadj)[*numofvertex_r];

      if (padjncyw != NULL)
	if (*padjncyw == NULL)
	  {
	    std::cerr<<"adding mockup values"<<std::endl;

	    *padjncyw = new WeightType[nEdge];
	    for (auto i = 0; i< nEdge; ++i)
	      (*padjncyw)[i] = 1.;
	  }
    }
  
  std::cerr<<*numofvertex_r<<" rows "<<(*pxadj)[*numofvertex_r]<<" non zero"<<std::endl;
}
