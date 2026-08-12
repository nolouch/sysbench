#ifndef SB_DRAIN_H
#define SB_DRAIN_H

#include <stdbool.h>
#include <stdint.h>

static inline bool sb_drain_is_complete(uint64_t queue, uint64_t inflight,
                                        uint64_t started, uint64_t completed)
{
  return queue == 0 && inflight == 0 && completed == started;
}

#endif
