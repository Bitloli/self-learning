#include <assert.h>  // assert
#include <fcntl.h>   // open
#include <limits.h>  // INT_MAX
#include <math.h>    // sqrt
#include <stdbool.h> // bool false true
#include <stdio.h>
#include <stdlib.h> // malloc sort
#include <string.h> // strcmp ..
#include <sys/mman.h>
#include <unistd.h> // sleep

int main(int argc, char *argv[]) {

  void *ptr = mmap(NULL, 8 * (1 << 21), PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB, -1, 0);

  if (ptr != NULL) {
    printf("success !\n");
  } else {
    printf("failed !\n");
  }
  char *a = (char *)ptr;
  *a = 'a';

  return 0;
}
