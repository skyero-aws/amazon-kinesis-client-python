#!/bin/bash
set -e

for i in {1..10}; do
  # TEMP CI: 4 shards so two workers have leases to balance
  if aws kinesis create-stream --stream-name $STREAM_NAME --shard-count 4; then
    break
  else
    echo "Stream creation failed, attempt $i/10. Waiting $((i * 3)) seconds..."
    sleep $((i * 3))
  fi
done
aws kinesis wait stream-exists --stream-name $STREAM_NAME