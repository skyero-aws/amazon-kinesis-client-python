#!/bin/sh

SETUP_SCRIPT="setup_list.py"
JAR_FILE="amazon-kinesis-client-multilang-3.0.3-SNAPSHOT.jar"
JAR_DIR="amazon_kclpy/jars"

python "${SETUP_SCRIPT}" download_jars && \
python "${SETUP_SCRIPT}" install && \
(cd "${JAR_DIR}" && jar xf "${JAR_FILE}") && echo "UNZIPPED JAR" && \
pwd && python "${SETUP_SCRIPT}" download_more_jars && \
python "${SETUP_SCRIPT}" install_more

if [ $? -eq 0 ]; then
  echo "Setup success"
else
  echo "Setup failure"
  exit 1
fi