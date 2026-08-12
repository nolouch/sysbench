#!/bin/sh
set -eu

sysbench_bin=${SYSBENCH_BIN:-./src/sysbench}
tmpdir=$(mktemp -d /tmp/sysbench-drain.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/slow.lua" <<'LUA'
function event()
  local until_at = os.clock() + 0.02
  while os.clock() < until_at do end
end
LUA

"$sysbench_bin" --threads=2 --time=30 --rate=200 \
  --report-interval=1 "$tmpdir/slow.lua" run >"$tmpdir/run.log" 2>&1 &
pid=$!
sleep 2
kill -USR2 "$pid"
wait "$pid"

marker=$(grep 'client_drain_v1 ' "$tmpdir/run.log" | tail -1)
test -n "$marker"
printf '%s\n' "$marker" | grep -q 'final_queue=0 inflight=0 outcome=drained'

started=$(printf '%s\n' "$marker" | sed -n 's/.* started=\([0-9][0-9]*\).*/\1/p')
final_completed=$(printf '%s\n' "$marker" | sed -n 's/.* completed=\([0-9][0-9]*\).*/\1/p')
test -n "$started"
test -n "$final_completed"
test "$started" -eq "$final_completed"

# The final admitted count must be identical to the count recorded when the
# event generator first observes admission stop.
offered=$(printf '%s\n' "$marker" | sed -n 's/.* offered=\([0-9][0-9]*\).*/\1/p')
last=$(sed -n 's/.*client_drain_admission_v1 offered=\([0-9][0-9]*\).*/\1/p' "$tmpdir/run.log" | tail -1)
test -n "$offered"
test -n "$last"
test "$offered" -eq "$last"

printf 'SIGUSR2 drain smoke passed: %s\n' "$marker"
