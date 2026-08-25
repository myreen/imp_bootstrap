#include "gc_stack.h"

extern value body(struct thread_info *);

int main(void) {
  struct thread_info *tinfo = make_tinfo();
  (void)body(tinfo);
  return 0;
}
