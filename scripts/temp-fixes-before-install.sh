#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

################################################################################
# This script will fix known issues during installing Zowe
#
# This script should be placed into target image zOSaaS layer to start.
# 
# FIXME: eventually this script should be empty
################################################################################

SCRIPT_NAME=$(basename "$0")
CI_ZOWE_ROOT_DIR=$1
FULL_EXTRACTED_ZOWE_FOLDER=$2
echo "[${SCRIPT_NAME}] started ..."
echo "[${SCRIPT_NAME}]    CI_ZOWE_ROOT_DIR           : $CI_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]    FULL_EXTRACTED_ZOWE_FOLDER : $FULL_EXTRACTED_ZOWE_FOLDER"
CI_PWD=$(pwd)


################################################################################
# NODE_HOME is not specified on the pre-reqs image
if [ -z "$NODE_HOME" ]; then
  echo "[${SCRIPT_NAME}] NODE_HOME is missing, need to fix:"
  export NODE_HOME=/Z23B/usr/lpp/IBM/cnj/IBM/node-v6.13.0-os390-s390x
else
  echo "[${SCRIPT_NAME}] NODE_HOME is in place, no need to fix."
fi
echo "[${SCRIPT_NAME}] NODE_HOME=$NODE_HOME"

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
