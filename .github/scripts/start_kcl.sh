#!/bin/bash
set -e
set -o pipefail

chmod +x .github/resources/github_workflow.properties
chmod +x samples/sample_kclpy_app.py

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties .github/resources/github_workflow.properties)
  gtimeout $RUN_TIME_SECONDS $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Linux" || "$RUNNER_OS" == "Windows" ]]; then
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties .github/resources/github_workflow.properties)
  # TEMP CI: trickle traffic and a second worker so lease balancing runs
  # Near-idle, sporadic traffic: one record every 15s with a random partition key, so it lands on a random shard
  python -u -c '
import random, sys, time
import boto3
kinesis = boto3.client("kinesis", region_name="us-east-1")
while True:
    partition_key = str(random.randint(0, 10**9))
    try:
        response = kinesis.put_record(StreamName=sys.argv[1], Data=b"tick", PartitionKey=partition_key)
        print("Put record with partition key {} into {}".format(partition_key, response["ShardId"]))
    except Exception as e:
        print("Failed to put record: {}".format(e))
    time.sleep(15)
' "$STREAM_NAME" > putter.log 2>&1 &
  PUTTER_PID=$!
  # Start the second worker 30s later so the workers don't race to create the lease table; exec keeps
  # WORKER_2_PID pointing at timeout so the trap below can stop it
  (sleep 30; exec timeout $((RUN_TIME_SECONDS - 30)) $KCL_COMMAND) > kcl_output_2.log 2>&1 &
  WORKER_2_PID=$!
  # Stop background processes however this step exits
  trap 'kill $PUTTER_PID $WORKER_2_PID 2>/dev/null || true' EXIT
  timeout $RUN_TIME_SECONDS $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
  wait $WORKER_2_PID || true
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

echo "==========ERROR LOGS=========="
grep -i error kcl_output.log || echo "No errors found in logs"

# TEMP CI: print the second worker's and putter's logs (collapsed) so they are in the job output
if [[ -f kcl_output_2.log ]]; then
  echo "==========WORKER 2 ERROR LOGS=========="
  grep -i error kcl_output_2.log || echo "No errors found in worker 2 logs"
  echo "::group::Worker 2 KCL log (kcl_output_2.log)"
  cat kcl_output_2.log
  echo "::endgroup::"
  echo "::group::Word putter log (putter.log)"
  cat putter.log || true
  echo "::endgroup::"
fi