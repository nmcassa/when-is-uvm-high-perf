#include <iostream>
#include <chrono>


__global__ void polynomial (float* array, float* poly, uint64_t degree, uint64_t n) {
  long index = ((long)blockIdx.x)*blockDim.x+threadIdx.x;

  if (index >= n)
    return;

  float x = array[index];

  float out = 0.;
  float xtothepowerof = 1.;
  for (uint64_t i=0; i<=degree; ++i) {
    out += xtothepowerof*poly[i];
    xtothepowerof *= x;
  }

  array[index] = out;
  //return out;
}


void polynomial_expansion (float* poly, uint64_t degree,
			   uint64_t n, float* array) {
  //TODO: Write code to use the GPU here!
  //code should write the output back to array

  uint64_t tpb = 256;
  uint64_t blocks = n/tpb + (n%tpb != 0);

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

  uint64_t n = atol(argv[1]); //TODO: atoi is an unsafe function
  uint64_t degree = atol(argv[2]);
  uint64_t nbiter = 1;

  float* array;
  float* poly;

  CUDAERRORMSG(cudaMallocHost((void**)&array, n*sizeof(float)));
  CUDAERRORMSG(cudaMallocHost((void**)&poly, (degree+1)*sizeof(float)));  

  for (uint64_t i=0; i<n; ++i)
    array[i] = 1.;

  for (uint64_t i=0; i<degree+1; ++i)
    poly[i] = 1.;

  
  std::chrono::time_point<std::chrono::system_clock> begin, end;
  begin = std::chrono::system_clock::now();

  float* d_array;
  float* d_poly;

  CUDAERRORMSG(cudaMalloc((void**)&d_array, ((long)n)*sizeof(float)));
  CUDAERRORMSG(cudaMalloc((void**)&d_poly, ((long)degree+1)*sizeof(float)));

  CUDAERRORMSG(cudaMemcpy(d_array, array, ((long)n)*sizeof(float), cudaMemcpyHostToDevice));
  CUDAERRORMSG(cudaMemcpy(d_poly, poly, ((long)degree+1)*sizeof(float), cudaMemcpyHostToDevice));

  
  for (uint64_t iter = 0; iter<nbiter; ++iter)
    polynomial_expansion (d_poly, degree, n, d_array);



  CUDAERRORMSG(cudaMemcpy(array, d_array, ((long)n)*sizeof(float), cudaMemcpyDeviceToHost));

  //to trap the error from the kernel launch
  CUDAERRORMSG(cudaGetLastError());

  end = std::chrono::system_clock::now();
  std::chrono::duration<double> totaltime = (end-begin)/nbiter;

  {
    bool correct = true;
    uint64_t ind;
    for (uint64_t i=0; i< n; ++i) {
      if (fabs(array[i]-(degree+1))>0.01) {
        correct = false;
	ind = i;
	if (!correct) break;
      }
    }
    if (!correct)
      std::cerr<<"Result is incorrect. In particular array["<<ind<<"] should be "<<degree+1<<" not "<< array[ind]<<std::endl;
  }
  

  std::cerr<<array[0]<<std::endl;
  std::cout<<n<<" "<<degree<<" "<<totaltime.count()<<std::endl;

  CUDAERRORMSG(cudaFreeHost(array));
  CUDAERRORMSG(cudaFreeHost(poly));
  
  CUDAERRORMSG(cudaFree(d_array));
  CUDAERRORMSG(cudaFree(d_poly));

  return 0;
}
