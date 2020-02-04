#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

################################################################################
# This script will fix known issues during installing Zowe
#
# This script should be placed into target image zOSaaS layer to start.
# 
# FIXME: eventually this script should be empty
################################################################################

SCRIPT_NAME=$(basename "$0")
FULL_EXTRACTED_ZOWE_FOLDER=$1
echo "[${SCRIPT_NAME}] started ..."
echo "[${SCRIPT_NAME}]    FULL_EXTRACTED_ZOWE_FOLDER : $FULL_EXTRACTED_ZOWE_FOLDER"

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
