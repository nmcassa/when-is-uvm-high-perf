#include <iostream>
#include <chrono>
#include <vector>

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
			   uint64_t n, float* array, cudaStream_t cuda_stream = 0) {
  //TODO: Write code to use the GPU here!
  //code should write the output back to array

  uint64_t tpb = 256;
  uint64_t blocks = n/tpb + (n%tpb != 0);

  polynomial<<<blocks, tpb, 0, cuda_stream>>> (array, poly, degree, n);

}


void CUDAERRORMSG(cudaError_t err) {
  if (err != cudaSuccess) {
    std::cerr<< cudaGetErrorString(err)<<std::endl;
  }

}

int main (int argc, char* argv[]) {
  //TODO: add usage
  
  if (argc < 5) {
     std::cerr<<"usage: "<<argv[0]<<" n degree nbstreams chunksize"<<std::endl;
     return -1;
  }

  uint64_t n = atol(argv[1]); //TODO: atoi is an unsafe function
  uint64_t degree = atol(argv[2]);
  uint64_t nbiter = 1;

  //float* array = new float[n];
  //float* poly = new float[degree+1];

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

  float* d_poly;

  CUDAERRORMSG(cudaMalloc((void**)&d_poly, ((long)degree+1)*sizeof(float)));


  CUDAERRORMSG(cudaMemcpy(d_poly, poly, ((long)degree+1)*sizeof(float), cudaMemcpyHostToDevice));

  uint64_t nbstream = std::atol(argv[3]);
  uint64_t chunksize = std::atol(argv[4]);

  std::vector<cudaStream_t> streams;
  std::vector<float*> stream_array_buffer;
  for (auto i=0; i<nbstream; ++i) {
    cudaStream_t st;
    CUDAERRORMSG(cudaStreamCreate(&st));
    streams.push_back(st);

    float* sb;
    CUDAERRORMSG(cudaMalloc((void**)&sb, ((long)chunksize)*sizeof(float)));
    stream_array_buffer.push_back(sb);
  }
  
  for (uint64_t iter = 0; iter<nbiter; ++iter) {
    auto nbchunk = (n+chunksize-1)/chunksize;
    
    for (uint64_t chunkid=0; chunkid<nbchunk;++chunkid) {
      auto which_stream = chunkid%nbstream;
      auto offset = chunkid*chunksize;
      auto localsize = chunksize;
      if (chunkid == nbchunk-1) {
	localsize = n-offset;
      }

      
      CUDAERRORMSG(cudaMemcpyAsync(stream_array_buffer[which_stream], array+offset, localsize*sizeof(float), cudaMemcpyHostToDevice));
      polynomial_expansion (d_poly, degree, localsize, stream_array_buffer[which_stream], streams[which_stream]);

      CUDAERRORMSG(cudaMemcpyAsync(array+offset, stream_array_buffer[which_stream], localsize*sizeof(float), cudaMemcpyDeviceToHost));
     
    }
  }
  
  for (auto st: streams) {
    CUDAERRORMSG(cudaStreamSynchronize(st));
  }
      
  
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

  CUDAERRORMSG(cudaFree(d_poly));

  for (auto p : stream_array_buffer) {
    CUDAERRORMSG(cudaFree(p));
  }

  for (auto st: streams) {
    CUDAERRORMSG(cudaStreamDestroy(st));
  }

  return 0;
}
