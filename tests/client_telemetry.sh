#!/bin/sh
set -eu

sysbench_bin=${SYSBENCH_BIN:-./src/sysbench}
output=$(mktemp)
trap 'rm -f "$output"' EXIT

"$sysbench_bin" cpu --threads=2 --rate=40 --time=2 --report-interval=1 run \
  >"$output" 2>&1

# Existing human output remains present.
grep -Eq 'queue length: [0-9]+ concurrency: [0-9]+' "$output"
# SQL/Lua workloads use db_report_intermediate(), not the default CPU handler.
grep -A40 '^void db_report_intermediate' src/db_driver.c |
  grep -q 'sb_report_client_telemetry(stat)'
# New line is one stable, machine-parseable record with both interval and
# cumulative lifecycle counters and deadline-to-start delay.
grep -Eq 'client_telemetry_v1 interval_s=[0-9.]+ scheduled=[1-9][0-9]* offered=[1-9][0-9]* sent=[1-9][0-9]* started=[1-9][0-9]* completed=[1-9][0-9]* scheduled_total=[1-9][0-9]* offered_total=[1-9][0-9]* sent_total=[1-9][0-9]* started_total=[1-9][0-9]* completed_total=[1-9][0-9]* send_delay_avg_ms=[0-9.]+ send_delay_max_ms=[0-9.]+ queue=[0-9]+ inflight=[0-9]+ errors=0 timeouts=0' "$output"

awk '
/client_telemetry_v1/ {
  for (i=1; i<=NF; i++) { split($i, kv, "="); v[kv[1]]=kv[2] }
  if (v["scheduled_total"] < v["offered_total"] ||
      v["offered_total"] < v["sent_total"] ||
      v["sent_total"] < v["started_total"] ||
      v["started_total"] < v["completed_total"]) exit 1
  seen++
}
END { if (seen < 1) exit 1 }
' "$output"

echo "client telemetry integration: OK"
