#!/bin/bash
set -e

set -o pipefail

echo "RUNNER_OS: $RUNNER_OS"
KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)

if [[ "$RUNNER_OS" == "macOS-latest" ]]; then
  brew install coreutils
  gtimeout 60 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
else
  timeout 60 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
fi