#!/bin/bash

aws kinesis delete-stream --stream-name $STREAM_NAME || true

for i in 1 2 3; do
  aws dynamodb delete-table --table-name $APP_NAME && break ||
  echo "Retrying DynamoDB Table deletion in 10s" && sleep 10
done
for SUFFIX in "-CoordinatorState" "-WorkerMetricStats" "-LeaseManagement"; do
  if aws dynamodb describe-table --table-name $APP_NAME$SUFFIX &>/dev/null; then
    echo "Deleting table $APP_NAME$SUFFIX"
    aws dynamodb delete-table --table-name $APP_NAME$SUFFIX || true
  fi
done