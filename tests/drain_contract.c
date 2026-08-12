#include <assert.h>
#include "sb_drain.h"

int main(void)
{
  assert(sb_drain_is_complete(0, 0, 42, 42));
  assert(!sb_drain_is_complete(1, 0, 42, 42));
  assert(!sb_drain_is_complete(0, 1, 42, 42));
  assert(!sb_drain_is_complete(0, 0, 42, 41));
  return 0;
}
