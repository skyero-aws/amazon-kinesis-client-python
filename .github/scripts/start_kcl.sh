#!/bin/bash
set -e
set -o pipefail

chmod +x samples/sample.properties
chmod +x samples/sample_kclpy_app.py

echo "checking file permissions: "
ls -la samples/sample.properties
ls -la samples/sample_kclpy_app.py

# Get records from stream to verify they exist before continuing
SHARD_ITERATOR=$(aws kinesis get-shard-iterator --stream-name $STREAM_NAME --shard-id shardId-000000000000 --shard-iterator-type TRIM_HORIZON --query 'ShardIterator' --output text)
INITIAL_RECORDS=$(aws kinesis get-records --shard-iterator $SHARD_ITERATOR)
RECORD_COUNT_BEFORE=$(echo $INITIAL_RECORDS | jq '.Records | length')

echo "Found $RECORD_COUNT_BEFORE records in stream before KCL start"

# Manipulate logging method for Windows
if [[ "$RUNNER_OS" == "Windows" ]]; then
  cat > fix_log.py << 'EOF'
import re

with open('samples/sample_kclpy_app.py', 'r') as f:
    content = f.read()

fixed_content = re.sub(
    r'def log\(self, message\):.*?with open\([^)]+\) as f:.*?f\.write\([^)]+\).*?sys\.stderr\.write\(message\)',
    'def log(self, message):\n        sys.stderr.write(message + "\\n")',
    content,
    flags=re.DOTALL
)

with open('samples/sample_kclpy_app.py', 'w') as f:
    f.write(fixed_content)
EOF

  # Run the Python script to fix the log method
  python fix_log.py
fi

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  gtimeout 180 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Linux" ]]; then
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  timeout 180 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  timeout 180 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

echo "---------ERROR LOGS HERE-------"
grep -i error kcl_output.log || echo "No errors found in logs"