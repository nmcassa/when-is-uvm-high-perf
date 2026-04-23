/////////////////////////////////////////////////////////////////////////////
//
// Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
//
// Please refer to the NVIDIA end user license agreement (EULA) associated
// with this source code for terms and conditions that govern your use of
// this software. Any use, reproduction, disclosure, or distribution of
// this software and related documentation outside the terms of the EULA
// is strictly prohibited.
//
/////////////////////////////////////////////////////////////////////////////

#ifndef HELPER_CUDA_H
#define HELPER_CUDA_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <complex>

//#include <helper_string.h>

#include <cuda_runtime.h>

////////////////////////////////////////////////////////////////////////////////
// These are CUDA Helper functions

    // This will output the proper CUDA error strings in the event that a CUDA host call returns an error
    #define checkCudaErrors(err)           __checkCudaErrors (err, __FILE__, __LINE__)

    inline void __checkCudaErrors( cudaError err, const char *file, const int line )
    {
        if( cudaSuccess != err) {
		    fprintf(stderr, "%s(%i) : CUDA Runtime API error %d: %s.\n",
                    file, line, (int)err, cudaGetErrorString( err ) );
            exit(-1);
        }
    }

    // This will output the proper error string when calling cudaGetLastError
    #define getLastCudaError(msg)      __getLastCudaError (msg, __FILE__, __LINE__)

    inline void __getLastCudaError( const char *errorMessage, const char *file, const int line )
    {
        cudaError_t err = cudaGetLastError();
        if( cudaSuccess != err) {
            fprintf(stderr, "%s(%i) : getLastCudaError() CUDA error : %s : (%d) %s.\n",
                    file, line, errorMessage, (int)err, cudaGetErrorString( err ) );
            exit(-1);
        }
    }


    #define checkCusparseError(err)           __checkCusparseError (err, __FILE__, __LINE__)

    inline void __checkCusparseError( cusparseStatus_t err, const char *file, const int line )
    {
        if( CUSPARSE_STATUS_SUCCESS != err) {
		    fprintf(stderr, "%s(%i) : CUSPARSE Runtime API error %s (%d): %s.\n",
			    file, line, cusparseGetErrorName(err), (int)err, cusparseGetErrorString( err ) );
            exit(-1);
        }
    }


#ifndef MAX
#define MAX(a,b) (a > b ? a : b)
#endif


template <typename T>
cudaDataType get_cusparse_datatype() {
    // Check the second template parameter T
    if constexpr (std::is_same_v<T, float>) {
        return CUDA_R_32F;
    } 
    else if constexpr (std::is_same_v<T, double>) {
        return CUDA_R_64F;
    } 
    else if constexpr (std::is_same_v<T, std::complex<float>>) {
        return CUDA_C_32F;
    } 
    else if constexpr (std::is_same_v<T, std::complex<double>>) {
        return CUDA_C_64F;
    } 
    else if constexpr (std::is_same_v<T, int>) {
        return CUDA_R_32I;
    }
    else {
        // Fallback or error for unsupported types
        static_assert(std::is_same_v<T, float>, "Unsupported cuSPARSE type!");
    }
}

template <typename I>
constexpr cusparseIndexType_t get_cusparse_index_type() {
    if constexpr (std::is_same_v<I, int32_t> || std::is_same_v<I, int>) {
        return CUSPARSE_INDEX_32I;
    } else if constexpr (std::is_same_v<I, int64_t> || std::is_same_v<I, long long>) {
        return CUSPARSE_INDEX_64I;
    } else {
        static_assert(std::is_integral_v<I>, "Index must be a signed 32 or 64-bit integer");
        return CUSPARSE_INDEX_32I;
    }
}



#endif
