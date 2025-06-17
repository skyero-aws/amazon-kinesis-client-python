#!/bin/bash
set -e

if [[ "$RUNNER_OS" == "macOS" ]]; then
  sed -i "" "s/kclpysample/$STREAM_NAME/g" samples/sample.properties
  sed -i "" "s/PythonKCLSample/$APP_NAME/g" samples/sample.properties
  grep -v "idleTimeBetweenReadsInMillis" samples/sample.properties > samples/temp.properties
  echo "idleTimeBetweenReadsInMillis = 250" >> samples/temp.properties
  mv samples/temp.properties samples/sample.properties
elif [[ "$RUNNER_OS" == "Linux" ]]; then
  sed -i "s/kclpysample/$STREAM_NAME/g" samples/sample.properties
  sed -i "s/PythonKCLSample/$APP_NAME/g" samples/sample.properties
  sed -i "/idleTimeBetweenReadsInMillis/c\idleTimeBetweenReadsInMillis = 250" samples/sample.properties
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  sed -i "s/kclpysample/$STREAM_NAME/g" samples/sample.properties
  sed -i "s/PythonKCLSample/$APP_NAME/g" samples/sample.properties
  sed -i "/idleTimeBetweenReadsInMillis/c\idleTimeBetweenReadsInMillis = 250" samples/sample.properties
  sed -i 's/executableName = sample_kclpy_app.py/executableName = python sample_kclpy_app.py/' samples/sample.properties
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

cat samples/sample.properties