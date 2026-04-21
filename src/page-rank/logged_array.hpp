#ifndef LOGGED_ARRAY
#define LOGGED_ARRAY

#include <cstddef>
#include <iostream>
#include <sstream>
#include <omp.h>

class logtextomp {
  static std::ofstream* out;
  static std::ofstream meta;

public:
  static void create(void* add, size_t s, const std::string & name) {
    if (!meta.is_open())
      meta.open("logme.meta");
    if (out == NULL) {
      out = new std::ofstream[omp_get_num_procs()];
    }
    
    meta<<add<<" "<<s<<" "<<name<<'\n';
  }

  static void log (char type, void* add, size_t s) {
    if (out == NULL) {
      out = new std::ofstream[omp_get_num_procs()];
    }
    int tid = omp_get_thread_num();

    if (!out[tid].is_open()) {
      std::stringstream ss; 
      ss<<"logme.txt."<<tid;
      out[tid].open(ss.str());
    }
    
    out[tid]<<type<<" "<<add<<" "<<s<<'\n';
  }
};


class logtext {
  static std::ofstream out;
  static std::ofstream meta;

public:
  static void create(void* add, size_t s, const std::string & name) {
    if (!meta.is_open())
      meta.open("logme.meta");
    
    meta<<add<<" "<<s<<" "<<name<<'\n';
  }

  static void log (char type, void* add, size_t s) {
    if (!out.is_open())
      out.open("logme.txt");
    
    out<<type<<" "<<add<<" "<<s<<'\n';
  }
};


class logcout {
public:
  static void create(void* add, size_t s, const std::string& name ) {
    std::cout<<add<<" "<<s<<" "<<name<<'\n';

  }

  static void log (char type, void* add, size_t s) {
    std::cout<<type<<" "<<add<<" "<<s<<"\n";
  }
};

class lognull {
public:
  static void create(void* , size_t , const std::string& ) {

  }

  static void log (char , void* , size_t) {
    
  }
};

class logbin {
  static std::ofstream out;
  
public:
  static void create(void* , size_t , const std::string&) {

  }

  static void log (char type, void* add, size_t s) {
    if (!out.is_open())
      out.open("logme.bin");
    out.write (&type, sizeof(type));
    out.write ((char*)&add, sizeof(add));
    out.write ((char*)&s, sizeof(s));
  }
};

template<class T, class LOG>
struct WRAP {
  T* data;
  WRAP(T* add) {
    data = add;
  }

  T& operator=(const T& a) {
    LOG::log('w', data, sizeof(T));
    *data = a;
    return *data;
  }

  operator T () {
    LOG::log('r', data, sizeof(T));
    return *data;
  }

  T operator+(const T& a) {
    LOG::log('r', data, sizeof(T));
    return a+*data;
  }


  const T& operator+=(const T& a) {
    LOG::log('r', data, sizeof(T));
    LOG::log('w', data, sizeof(T));
    return *data += a;
  }


  const T& operator*=(const T& a) {
    LOG::log('r', data, sizeof(T));
    LOG::log('w', data, sizeof(T));
    return *data *= a;
  }

  T operator-(const T& a) {
    LOG::log('r', data, sizeof(T));
    return a-*data;
  }


  T operator*(const T& a) {
    LOG::log('r', data, sizeof(T));
    return a* (*data);
  }

  T operator/(const T& a) {
    LOG::log('r', data, sizeof(T));
    return a/ (*data);
  }
   
};

template<class T, class LOG>
class LoggedArray
{
  T* data;
  bool shoulddelete;
  int offset;
public:
  LoggedArray (size_t s, std::string name="") {
    offset = 0;
    data = new T[s];
    shoulddelete = true;

    LOG::create (data, s, name);
  }

  LoggedArray (T* d, std::size_t s=-1, std::string name="") {
    offset = 0;
    data = d;
    shoulddelete = false;

    LOG::create (data, s, name);
  }


  ~LoggedArray() {
    close();
  }

  void close() {
    if (shoulddelete)
      delete[] data;
  }

  inline LoggedArray<T,LOG> operator+ (int off) {
    LoggedArray<T,LOG> ret = *this;
    ret.offset += off;
    return ret;
  }

  inline LoggedArray<T,LOG>& operator++ () {
    offset ++;
    return *this;
  }


  inline LoggedArray<T,LOG> operator++ (int) {
    LoggedArray<T,LOG> ret = *this;
    ++ret;
    return ret;
  }

  inline bool operator < (const LoggedArray& b) {
    return this->data+this->offset < b.data+b.offset;
  }


  inline WRAP<T,LOG> operator* () {

    return (*this)[0];
  }

  inline WRAP<T,LOG> operator[] (int i) {

    return WRAP<T,LOG>(data+offset+i);
  }

  inline WRAP<const T,LOG> operator[] (int i) const {
    
    return WRAP<T,LOG>(data+offset+i);
  }
};

#endif
