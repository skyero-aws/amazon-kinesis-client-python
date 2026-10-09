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
  # "dog" hashes to shardId-000000000000 only, leaving shards 1-3 idle (one hot shard, like the customer)
  sample_kinesis_wordputter.py --stream $STREAM_NAME -w dog -p 15 > putter.log 2>&1 &
  PUTTER_PID=$!
  timeout $RUN_TIME_SECONDS $KCL_COMMAND > kcl_output_2.log 2>&1 &
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