#!/bin/bash
set -e

NUM_LEASES_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --query "Count" --output text || echo "0")
NUM_CHECKPOINTS_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --filter-expression "attribute_exists(checkpoint) AND checkpoint <> :trim_horizon" --expression-attribute-values '{":trim_horizon": {"S": "TRIM_HORIZON"}}' --query "Count" --output text || echo "0")

echo "Found $NUM_LEASES_FOUND leases and $NUM_CHECKPOINTS_FOUND non-TRIM-HORIZON checkpoint in DynamoDB"

echo "Printing checkpoint values"
aws dynamodb scan --table-name $APP_NAME --projection-expression "leaseKey,checkpoint" --output json

# TEMP CI: confirm useAbsoluteReBalanceThreshold was parsed and applied by the leader
echo "==========REBALANCE CONFIG=========="
grep -h "Processing (key=" kcl_output*.log | sed 's/.*Processing/Processing/' | sort | uniq -c
echo "==========REBALANCE RANGES (expect upper/lower = avg +/- 5, upper capped at 100), count per range=========="
grep -h "Range for re-balance" kcl_output*.log | sed 's/.*Range for/Range for/' | sort | uniq -c
echo "==========BALANCING SUMMARY (both workers)=========="
echo "Re-balance checks:          $(cat kcl_output*.log | grep -c 'Range for re-balance' || true)"
echo "Leases picked to move:      $(cat kcl_output*.log | grep -c 'Leases taken from worker' || true)"
echo "Moves blocked by receiver:  $(cat kcl_output*.log | grep -c 'No worker to assign anymore' || true)"
echo "Graceful lease handoffs:    $(cat kcl_output*.log | grep -c 'Initiated graceful lease handoff' || true)"
echo "==========HANDOFFS PER SHARD=========="
grep -h "Initiated graceful lease handoff" kcl_output*.log | grep -o "shardId-[0-9]*" | sort | uniq -c || true
echo "==========LAST 3 BALANCING DECISIONS=========="
grep -h -A1 "Range for re-balance" kcl_output*.log | tail -6
if ! grep -q "Processing (key=useAbsoluteReBalanceThreshold, value=true)" kcl_output*.log; then
  echo "Test failed: useAbsoluteReBalanceThreshold was not processed"
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