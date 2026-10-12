#!/bin/bash
set -e

NUM_LEASES_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --query "Count" --output text || echo "0")
NUM_CHECKPOINTS_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --filter-expression "attribute_exists(checkpoint) AND checkpoint <> :trim_horizon" --expression-attribute-values '{":trim_horizon": {"S": "TRIM_HORIZON"}}' --query "Count" --output text || echo "0")

echo "Found $NUM_LEASES_FOUND leases and $NUM_CHECKPOINTS_FOUND non-TRIM-HORIZON checkpoint in DynamoDB"

echo "Printing checkpoint values"
aws dynamodb scan --table-name $APP_NAME --projection-expression "leaseKey,checkpoint" --output json

# TEMP CI: confirm the re-balance settings were parsed and applied by the leader
if [[ "$THRESHOLD_MODE" == "absolute" ]]; then EXPECTED_ABSOLUTE=true; else EXPECTED_ABSOLUTE=false; fi
echo "==========MODE: $THRESHOLD_MODE (useAbsoluteReBalanceThreshold=$EXPECTED_ABSOLUTE)=========="
echo "==========REBALANCE CONFIG=========="
grep -h "Processing (key=" kcl_output*.log | sed 's/.*Processing/Processing/' | sort | uniq -c
echo "==========WORKER METRIC USED (expect C = CPU, not T = throughput), fleet average rounded=========="
grep -h "fleet level average" kcl_output*.log | sed -E 's/.*fleet level average : //; s/=([0-9]+)\.[0-9]+/=\1/' | sort | uniq -c | sort -rn | head -10
echo "==========LAST 5 PER-WORKER METRICS=========="
grep -h "Active WorkerMetricStats" kcl_output*.log | tail -5 | while read -r line; do
  echo "$line" | grep -o "workerId=[0-9a-f]\{8\}\|metricStats={[A-Z]=\[[^]]*\]}" | paste -sd' ' -
done
if [[ "$THRESHOLD_MODE" == "absolute" ]]; then
  echo "==========REBALANCE RANGES (expect avg +/- 5, upper capped at 100), rounded, count per range=========="
else
  echo "==========REBALANCE RANGES (expect avg * (1 +/- 0.10)), rounded, count per range=========="
fi
grep -h "Range for re-balance" kcl_output*.log | sed -E 's/.*Range for/Range for/; s/([0-9]+\.[0-9])[0-9]*/\1/g' | sort | uniq -c | sort -rn | head -15
echo "==========HANDOFFS PER MINUTE=========="
grep -h "Initiated graceful lease handoff" kcl_output*.log | grep -o "^[0-9-]* [0-9]*:[0-9]*" | uniq -c || true
echo "==========BALANCING SUMMARY (both workers)=========="
echo "Re-balance checks:          $(cat kcl_output*.log | grep -c 'Range for re-balance' || true)"
echo "Leases picked to move:      $(cat kcl_output*.log | grep -c 'Leases taken from worker' || true)"
echo "Moves blocked by receiver:  $(cat kcl_output*.log | grep -c 'No worker to assign anymore' || true)"
echo "Graceful lease handoffs:    $(cat kcl_output*.log | grep -c 'Initiated graceful lease handoff' || true)"
echo "==========HANDOFFS PER SHARD=========="
grep -h "Initiated graceful lease handoff" kcl_output*.log | grep -o "shardId-[0-9]*" | sort | uniq -c || true
echo "==========LAST 3 BALANCING DECISIONS=========="
grep -h -A1 "Range for re-balance" kcl_output*.log | tail -6
if ! grep -q "Processing (key=useAbsoluteReBalanceThreshold, value=$EXPECTED_ABSOLUTE)" kcl_output*.log; then
  echo "Test failed: useAbsoluteReBalanceThreshold=$EXPECTED_ABSOLUTE was not processed"
  exit 1
fi
if ! grep -q "fleet level average : {C=" kcl_output*.log; then
  echo "Test failed: KCL did not balance on CPU metrics (container EKS detection did not take effect)"
  exit 1
fi
if ! grep -q "Range for re-balance" kcl_output*.log; then
  echo "Test failed: no re-balance range logged; lease balancing did not run"
  exit 1
fi

if [ "$NUM_LEASES_FOUND" -gt 0 ] && [ "$NUM_CHECKPOINTS_FOUND" -gt 0 ]; then
  echo "Test passed: Found both leases and non-TRIM_HORIZON checkpoints in DDB (KCL is fully functional)"
  exit 0
else
  echo "Test failed: KCL not fully functional"
  echo "Lease(s) found: $NUM_LEASES_FOUND"
  echo "non-TRIM_HORIZON checkpoint(s) found: $NUM_CHECKPOINTS_FOUND"
  exit 1
fi