#!/bin/bash
set -e

sample_kinesis_wordputter.py --stream $STREAM_NAME -w cat -w dog -w bird -w lobster -w octopus

# Get records from stream to verify they exist before continuing
# TEMP CI: count across all shards, since words may not land on shard 0 with 4 shards
RECORD_COUNT_BEFORE=0
for SHARD_ID in $(aws kinesis list-shards --stream-name $STREAM_NAME --query 'Shards[].ShardId' --output text); do
  SHARD_ITERATOR=$(aws kinesis get-shard-iterator --stream-name $STREAM_NAME --shard-id $SHARD_ID --shard-iterator-type TRIM_HORIZON --query 'ShardIterator' --output text)
  SHARD_RECORDS=$(aws kinesis get-records --shard-iterator $SHARD_ITERATOR)
  RECORD_COUNT_BEFORE=$((RECORD_COUNT_BEFORE + $(echo $SHARD_RECORDS | jq '.Records | length')))
done

if [ "$RECORD_COUNT_BEFORE" -eq 0 ]; then
  echo "No records found in stream. Test cannot proceed."
  exit 1
fi
echo "Found $RECORD_COUNT_BEFORE records in stream before KCL start"