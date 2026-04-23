#ifndef GRAPH_PART
#define GRAPH_PART

#include <patoh.h>

void hypergraph(int nVtx, int * adj, int* xadj, int* partvec, int nbpart)
{
  PaToH_Parameters args;
  //  PaToH_Initialize_Parameters(&args, PATOH_CONPART/*PATOH_CUTPART*/, PATOH_SUGPARAM_QUALITY);
  PaToH_Initialize_Parameters(&args, PATOH_CUTPART, PATOH_SUGPARAM_QUALITY);

  args._k = nbpart;
  args.MemMul_CellNet += 5;
  args.MemMul_Pins += 5;
  args.MemMul_General += 5;
  args.balance = .2;
  int* partweights = new int[args._k];

  int* xadjpme = new int [nVtx+1];
  int* adjpme = new int [xadj[nVtx]+nVtx];

  //adding myself to the nets
  {
    for (int i=0; i<= nVtx; ++i)
      xadjpme[i] = xadj[i]+i;

    for (int i= 0; i<nVtx; ++i) {
      adjpme[xadjpme[i]] = i;

      for (int p = xadj[i]; p!= xadj[i+1]; ++p) {
	adjpme[p-xadj[i]+xadjpme[i]+1] = adj[p];
      }

    }
    if (0)
      for (int i = 0; i<nVtx; ++i) {
	for (int p= xadjpme[i]; p!= xadjpme[i+1]; ++p) 
	  std::cerr<<adjpme[p]<<'\t';
	std::cerr<<std::endl;
      }
  }

  
  int *cwghts = new int[nVtx];
  int *nwghts = new int[nVtx];
  int cut = 0;


  for (int i=0; i<nVtx; i++)
    cwghts[i] = nwghts[i] = 1;

  int err = PaToH_Alloc(&args, nVtx, nVtx, 1, cwghts, nwghts, xadjpme, adjpme);
  if (err != 0)
    std::cerr<<"patoh error alloc"<<std::endl;

  PaToH_Part(&args, nVtx, nVtx, 1, 0, cwghts, nwghts,
	     xadjpme, adjpme, NULL, partvec, partweights, &cut);


  delete[] xadjpme;
  delete[] adjpme;
  delete[] cwghts;
  delete[] nwghts;
  delete[] partweights;
  PaToH_Free();
}

#endif
