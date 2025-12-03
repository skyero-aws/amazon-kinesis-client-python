#!/bin/bash
set -e

# Manipulate sample.properties file that the KCL application pulls properties from (ex: streamName, applicationName)
# Depending on the OS, different properties need to be changed
if [[ "$RUNNER_OS" == "macOS" ]]; then
  sed -i "" "s/kclpysample/$STREAM_NAME/g" .github/resources/sample.properties
  sed -i "" "s/PythonKCLSample/$APP_NAME/g" .github/resources/sample.properties
elif [[ "$RUNNER_OS" == "Linux" || "$RUNNER_OS" == "Windows" ]]; then
  sed -i "s/kclpysample/$STREAM_NAME/g" .github/resources/sample.properties
  sed -i "s/PythonKCLSample/$APP_NAME/g" .github/resources/sample.properties

  if [[ "$RUNNER_OS" == "Windows" ]]; then
    echo '@echo off' > samples/run_script.bat
    echo 'python %~dp0\sample_kclpy_app.py %*' >> samples/run_script.bat
    sed -i 's/executableName = sample_kclpy_app.py/executableName = samples\/run_script.bat/' .github/resources/sample.properties
  fi
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

cat .github/resources/sample.properties