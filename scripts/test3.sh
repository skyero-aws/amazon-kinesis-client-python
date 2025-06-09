#!/bin/sh

SETUP_SCRIPT_POM="setup.py"
SETUP_SCRIPT_LIST="setup_test.py"
JAR_FILE="amazon-kinesis-client-multilang-3.0.3-SNAPSHOT.jar"
JAR_DIR="amazon_kclpy/jars"

python "${SETUP_SCRIPT_LIST}" download_jars && \
python "${SETUP_SCRIPT_LIST}" install && \
python "${SETUP_SCRIPT_LIST}" download_more_jars && \
python "${SETUP_SCRIPT_LIST}" install_more

if [ $? -eq 0 ]; then
  echo "Setup success"
else
  echo "Setup failure"
  exit 1
fi