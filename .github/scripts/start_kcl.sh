#!/bin/bash
set -e
set -o pipefail

KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  gtimeout 5 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
else
  timeout 5 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
fi