#include <mpi.h>
#include <iostream>
#include <string>
#include <vector>
#include <stdlib.h>

#include "../timestamp.hpp"

//#define SIZE_BUFFER 1024*1024*64L
//#define SIZE_BUFFER 262000*4L
//#define SIZE_BUFFER 262*4L

int main(int argc, char* argv[]) {

  MPI_Init (&argc, &argv);


  int rank = -1;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int nbrank = -1;
  MPI_Comm_size(MPI_COMM_WORLD, &nbrank);

  if (argc != 3) {
    std::cerr<<"Usage: "<<argv[0]<<" fraction SIZE_BUFFER"<<std::endl;
    return -1;
  }

  double fraction= atof(argv[1]);
  long long int SIZE_BUFFER = atol(argv[2]);

  std::vector<char> buffer (SIZE_BUFFER);
  std::vector<int> partition (nbrank+1);
  std::vector<int> partsize (nbrank);

  partition[0] = 0;

  partition[1] = SIZE_BUFFER*fraction;
  
  for (int i = 2 ; i < nbrank; ++i) {
    int remainwork = SIZE_BUFFER-partition[i-1];
    int remainproc = nbrank - (i - 1);

    partition[i] = partition[i-1]+remainwork/remainproc;
  }


  partition[nbrank] = SIZE_BUFFER;
  

  for (int i=0; i<nbrank; ++i)
    partsize[i] = partition[i+1]-partition[i];


  util::timestamp beg;

  int nbiter = 20;

  for (int i=0; i< nbiter; ++i) {

    MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL,
		   &(buffer[0]), &(partsize[0]), &(partition[0]), MPI_CHAR,
		   MPI_COMM_WORLD);
  }

  MPI_Barrier(MPI_COMM_WORLD);

  util::timestamp end;


  if (rank == 0) {
    std::cout<<"allgather "<<SIZE_BUFFER<<" bytes with "<<nbrank<<" ranks and a fraction of "<<fraction<<" to rank0 in "<<(end-beg)/nbiter<<" seconds"<<std::endl;
  }

  MPI_Finalize();

  return 0;
}
