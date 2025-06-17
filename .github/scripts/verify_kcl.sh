#!/bin/bash
set -e

LEASE_EXISTS=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --query "Count" --output text || echo "0")
CHECKPOINT_EXISTS=$(aws dynamodb scan --table-name $APP_NAME --select "COUNT" --filter-expression "attribute_exists(checkpoint)" --query "Count" --output text || echo "0")

echo "Found $LEASE_EXISTS leases and $CHECKPOINT_EXISTS checkpoints in DynamoDB"

echo "Print checkpoint values"
aws dynamodb scan --table-name $APP_NAME --projection-expression "leaseKey,checkpoint" --output json

echo "Print KCL startup logs"
cat /tmp/kcl_startup.log || echo "KCL startup log file not found or empty"

echo "Checking Python script path and permissions"
ls -la samples/sample_kclpy_app.py || echo "Python script not found"

echo "Checking executableName in properties file"
grep "executableName" samples/sample.properties

echo "Checking Python interpreter"
which python
python --version

if [ "$LEASE_EXISTS" -gt 0 ] && [ "$CHECKPOINT_EXISTS" -gt 0 ]; then
  echo "Test passed: Found both leases and checkpoints in DDB (KCL is fully functional)"
  exit 0
else
  echo "Test failed: KCL not fully functional"
  echo "Lease(s) found: $LEASE_EXISTS"
  echo "Checkpoint(s) found: $CHECKPOINT_EXISTS"
  exit 1
fi