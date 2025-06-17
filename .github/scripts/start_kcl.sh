#!/bin/bash
set -e
set -o pipefail

KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  gtimeout 900 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
else
  timeout 900 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
fi