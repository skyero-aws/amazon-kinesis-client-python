#!/bin/bash
set -e
set -o pipefail

#if [[ "$RUNNER_OS" == "macOS" ]]; then
#  brew install coreutils
#  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
#  gtimeout 900 $KCL_COMMAND 2>&1 | tee kcl_output.log  || [ $? -eq 124 ]
#elif [[ "$RUNNER_OS" == "Linux" ]]; then
#  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
#  timeout 900 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
#elif [[ "$RUNNER_OS" == "Windows" ]]; then
#  KCL_COMMAND=$(amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties)
#  KCL_COMMAND=${KCL_COMMAND//sample_kclpy_app.py/python sample_kclpy_app.py}
#  timeout 900 $KCL_COMMAND 2>&1 | tee kcl_output.log || [ $? -eq 124 ]
#else
#  echo "Unknown OS: $RUNNER_OS"
#  exit 1
#fi

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties
elif [[ "$RUNNER_OS" == "Linux" ]]; then
  amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  amazon_kclpy_helper.py --print_command --java $(which java) --properties samples/sample.properties
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi