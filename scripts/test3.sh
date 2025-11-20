#!/bin/sh

SETUP_SCRIPT_LIST="setup_unified.py"

python "${SETUP_SCRIPT_LIST}" install

if [ $? -eq 0 ]; then
  echo "Setup success"
else
  echo "Setup failure"
  exit 1
fi