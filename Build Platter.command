#!/bin/bash
# Builds and installs the Platter menu bar app.
cd "$(dirname "$0")"
bash build.sh 2>&1 | tee build.log
echo
echo "Finished. You can close this window."
