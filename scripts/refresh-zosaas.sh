#!/bin/bash -e

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
# This script will reset zOSaaS volumes to /zaas1/techinfo/zVolumesZipped
# 
# This script should be placed into target image Ubuntu layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(pwd)
TASK_USERNAME=ibmsys1
PATH_ZIPPED=/zaas1/zimage/zVolumesZipped
PATH_UNZIPPED=/zaas1/zimage/zVolumes

# allow to exit by ctrl+c
function finish() {
  echo "[${SCRIPT_NAME}] interrupted"
}
trap finish SIGINT

################################################################################
# essential validations
# 1. if currently login as ibmsys1
WHOAMI=$(whoami)
if [ "$WHOAMI" != "$TASK_USERNAME" ]; then
  echo "[${SCRIPT_NAME}] not login as ${TASK_USERNAME}, exit"
  exit 1
fi
################################################################################
echo "[${SCRIPT_NAME}] refreshing zOSaaS started ..."

################################################################################
# check and stop current zOSaaS
AWSSTAT=$(awsstat | grep "Config file" || true)
# sample output
# 
# AWSSTT001E 1090 instance is not active
# 
# or
# 
# Config file: /zaas1/devmaps/zaas1,  3270port: 3270,  Instance: ibmsys1   
# DvNbr S/Ch --Mgr--- IO Count --PID-- -------------------Device Information-------------------
# ... (more devices list)
if [ -n "$AWSSTAT" ]; then
  echo "[${SCRIPT_NAME}] stopping current zOSaaS ..."
  sys_reset
  awsstop
  echo "[${SCRIPT_NAME}] current zOSaaS stopped."
  echo
else
  echo "[${SCRIPT_NAME}] zOSaaS is not running."
fi

################################################################################
# overwrite Zowe pre-req volumes

# clean previous volumes
echo "[${SCRIPT_NAME}] cleaning previous volumes..."
rm -fr $PATH_UNZIPPED/*

# get volume list
cd $PATH_ZIPPED
ZIPPED_VOLS=$(ls *.gz)

# extract zipped volumes
echo "[${SCRIPT_NAME}] extracting volumes from ${PATH_ZIPPED} to ${PATH_UNZIPPED} ..."
cd $PATH_ZIPPED
for x in $ZIPPED_VOLS; do
  echo "  - $x"
  xn=${x%".gz"}
  pigz -d -c $x > $PATH_UNZIPPED/$xn
done
echo "[${SCRIPT_NAME}] all volumes updated."

# checksum
echo "[${SCRIPT_NAME}] checking md5sum ... [skipped]"
# md5sum -c  zosaas_md5sums

# run temp fixes
cd $SCRIPT_PWD
if [ -f "temp-fixes-prereqs-image.sh" ]; then
  (exec bash -c "$SCRIPT_PWD/temp-fixes-prereqs-image.sh")
fi

################################################################################
# restart the image
echo "[${SCRIPT_NAME}] restarting zOSaaS ..."
sudo systemctl restart zaasHelper.service

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
