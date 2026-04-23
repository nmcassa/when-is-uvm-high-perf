#ifndef MEMUTILS_HEADER
#define MEMUTILS_HEADER

//#include <xmmintrin.h>

void evict_array_from_cache (void* ptr, size_t size) {
  const size_t CACHELINE = 64;
  
  char* rptr = static_cast<char*>(ptr);

  char* ptrend = rptr + size;
  for (; rptr< ptrend; rptr += CACHELINE) {
#ifdef MIC
    _mm_clevict(rptr,   _MM_HINT_T0);
    _mm_clevict(rptr,   _MM_HINT_T1);
#else
    //_mm_clflush(rptr);
#endif
  }
}

#endif
