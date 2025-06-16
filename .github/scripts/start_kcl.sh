#!/bin/bash
set -e

set -o pipefail

if [[ "$RUNNER_OS" == "macOS-latest" ]]; then
  brew install coreutils
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  gtimeout 90 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
else
  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
  timeout 90 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
fi