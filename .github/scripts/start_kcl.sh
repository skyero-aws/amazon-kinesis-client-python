#!/bin/bash
set -e
set -o pipefail

chmod +x samples/sample.properties
chmod +x samples/sample_kclpy_app.py

echo "checking file permissions: "
ls -la samples/sample.properties
ls -la samples/sample_kclpy_app.py

# Reset the checkpoint in DynamoDB to force starting from TRIM_HORIZON
echo "Resetting checkpoint for shardId-000000000000..."
aws dynamodb update-item \
  --table-name $APP_NAME \
  --key '{"leaseKey": {"S": "shardId-000000000000"}}' \
  --update-expression "SET checkpoint = :val" \
  --expression-attribute-values '{":val": {"S": "TRIM_HORIZON"}}' \
  --return-values NONE

# Get records from stream to verify they exist before continuing
SHARD_ITERATOR=$(aws kinesis get-shard-iterator --stream-name $STREAM_NAME --shard-id shardId-000000000000 --shard-iterator-type TRIM_HORIZON --query 'ShardIterator' --output text)
INITIAL_RECORDS=$(aws kinesis get-records --shard-iterator $SHARD_ITERATOR)
RECORD_COUNT_BEFORE=$(echo $INITIAL_RECORDS | jq '.Records | length')

echo "Found $RECORD_COUNT_BEFORE records in stream before KCL start"

# Manipulate logging method
cat > fix_log.py << 'EOF'
with open('samples/sample_kclpy_app.py', 'r') as f:
    content = f.read()

# Replace the log method with a simple version that writes to stderr
new_log = '''    def log(self, message):
        sys.stderr.write(message + "\\n")'''

# Find the start and end of the log method
start = content.find('    def log(self, message):')
end = content.find('        sys.stderr.write(message)', start)
if start >= 0 and end >= 0:
    end = content.find('\n', end) + 1
    fixed_content = content[:start] + new_log + content[end:]
    with open('samples/sample_kclpy_app.py', 'w') as f:
        f.write(fixed_content)
EOF

python fix_log.py

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  gtimeout 240 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Linux" ]]; then
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  timeout 240 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  timeout 300 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

echo "---------ERROR LOGS HERE-------"
grep -i error kcl_output.log || echo "No errors found in logs"