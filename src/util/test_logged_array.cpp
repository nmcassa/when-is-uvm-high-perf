#include "logged_array.hpp"

int main () {

  LoggedArray<int, logcout> foo (32);
  
  foo[2] = 4;
  foo[4] = foo[2] + 4;
  foo[2] += 4;
  foo[3] *= foo[2];

  return 0;
}
