#include <iostream>
#include <chrono>
#include <numeric>

__global__ void polynomial (float* array, float* poly, size_t degree, size_t n) {
  long index = ((long)blockIdx.x)*blockDim.x+threadIdx.x;

  if (index >= n)
    return;

  float x = array[index];

  float out = 0.;
  float xtothepowerof = 1.;
  for (size_t i=0; i<=degree; ++i) {
    out += xtothepowerof*poly[i];
    xtothepowerof *= x;
  }

  array[index] = out;
  //return out;
}


void polynomial_expansion (float* poly, size_t degree,
			   size_t n, float* array) {
  //TODO: Write code to use the GPU here!
  //code should write the output back to array

  size_t tpb = 256;
  size_t blocks = n/tpb + (n%tpb != 0);

  polynomial<<<blocks, tpb>>> (array, poly, degree, n);

}


void CUDAERRORMSG(cudaError_t err) {
  if (err != cudaSuccess) {
    std::cerr<< cudaGetErrorString(err)<<std::endl;
  }

}

int main (int argc, char* argv[]) {
  //TODO: add usage
  
  if (argc < 3) {
     std::cerr<<"usage: "<<argv[0]<<" n degree"<<std::endl;
     return -1;
  }

  size_t n = atol(argv[1]); //TODO: atoi is an unsafe function
  size_t degree = atol(argv[2]);
  size_t nbiter = 1;


  
  float* array;
  float* poly;

  CUDAERRORMSG(cudaMallocManaged((void**)&array, ((long)n)*sizeof(float)));
  CUDAERRORMSG(cudaMallocManaged((void**)&poly, ((long)degree+1)*sizeof(float)));
  
  
  for (size_t i=0; i<n; ++i)
    array[i] = 1.;

  for (size_t i=0; i<degree+1; ++i)
    poly[i] = 1.;

  
  std::chrono::time_point<std::chrono::system_clock> begin, end;
  begin = std::chrono::system_clock::now();

  
  for (size_t iter = 0; iter<nbiter; ++iter)
    polynomial_expansion (poly, degree, n, array);

  cudaDeviceSynchronize(); //
  
  //to trap the error from the kernel launch
  CUDAERRORMSG(cudaGetLastError());

  float sum = std::reduce(array, array+n);

  end = std::chrono::system_clock::now();
  std::chrono::duration<double> totaltime = (end-begin)/nbiter;

  {
    bool correct = true;
    size_t ind;
    for (size_t i=0; i< n; ++i) {
      if (fabs(array[i]-(degree+1))>0.01) {
        correct = false;
	ind = i;
	if (!correct) break;
      }
    }
    if (!correct)
      std::cerr<<"Result is incorrect. In particular array["<<ind<<"] should be "<<degree+1<<" not "<< array[ind]<<std::endl;
  }
  

  std::cerr<<array[0]<<" "<<sum<<std::endl;
  std::cout<<n<<" "<<degree<<" "<<totaltime.count()<<std::endl;

  std::cerr<<"array is "<<((uint64_t)n)*sizeof(float)/1000./1000./1000.<<" GB"<<std::endl;
  
  CUDAERRORMSG(cudaFree(array));
  CUDAERRORMSG(cudaFree(poly));
  

  return 0;
}
