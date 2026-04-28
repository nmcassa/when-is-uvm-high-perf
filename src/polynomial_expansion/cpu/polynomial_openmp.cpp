#include <iostream>
#include <chrono>

//
float polynomial (float x, float* poly, uint64_t degree) {
  float out = 0.;
  float xtothepowerof = 1.;
  for (uint64_t i=0; i<=degree; ++i) {
    out += xtothepowerof*poly[i];
    xtothepowerof *= x;
  }
  return out;
}

void polynomial_expansion (float* poly, uint64_t degree,
			   uint64_t n, float* array) {

#pragma omp parallel for schedule(dynamic,1024)
  for (uint64_t i=0; i< n; ++i) {
    array[i] = polynomial (array[i], poly, degree);
  }
}


int main (int argc, char* argv[]) {
  if (argc < 3) {
     std::cerr<<"usage: "<<argv[0]<<" n degree"<<std::endl;
     return -1;
  }

  uint64_t n = atol(argv[1]); //TODO: atoi is an unsafe function
  uint64_t degree = atol(argv[2]);
  uint64_t nbiter = 1;

  float* array = new float[n];
  float* poly = new float[degree+1];
  for (uint64_t i=0; i<n; ++i)
    array[i] = 1.;

  for (uint64_t i=0; i<degree+1; ++i)
    poly[i] = 1.;

  
  std::chrono::time_point<std::chrono::system_clock> begin, end;
  begin = std::chrono::system_clock::now();
  
  for (uint64_t iter = 0; iter<nbiter; ++iter)
    polynomial_expansion (poly, degree, n, array);

  end = std::chrono::system_clock::now();
  std::chrono::duration<double> totaltime = (end-begin)/nbiter;

  std::cerr<<array[0]<<std::endl;
  std::cout<<n<<" "<<degree<<" "<<totaltime.count()<<std::endl;

  delete[] array;
  delete[] poly;

  return 0;
}
