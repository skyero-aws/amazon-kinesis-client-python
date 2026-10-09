#!/bin/bash
set -e

NUM_LEASES_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --query "Count" --output text || echo "0")
NUM_CHECKPOINTS_FOUND=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --filter-expression "attribute_exists(checkpoint) AND checkpoint <> :trim_horizon" --expression-attribute-values '{":trim_horizon": {"S": "TRIM_HORIZON"}}' --query "Count" --output text || echo "0")

echo "Found $NUM_LEASES_FOUND leases and $NUM_CHECKPOINTS_FOUND non-TRIM-HORIZON checkpoint in DynamoDB"

echo "Printing checkpoint values"
aws dynamodb scan --table-name $APP_NAME --projection-expression "leaseKey,checkpoint" --output json

# TEMP CI: confirm useAbsoluteReBalanceThreshold was parsed and applied by the leader
echo "==========REBALANCE CONFIG=========="
grep -h "Processing (key=useAbsoluteReBalanceThreshold\|Processing (key=reBalanceThresholdPercentage" kcl_output*.log
echo "==========REBALANCE RANGES (expect upper/lower = avg +/- 5, upper capped at 100)=========="
grep -h -B2 "Range for re-balance" kcl_output*.log | tail -40
echo "==========LEASE HANDOFFS=========="
grep -h -c "Initiated graceful lease handoff" kcl_output*.log || true
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