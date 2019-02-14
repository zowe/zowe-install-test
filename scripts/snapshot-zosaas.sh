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
# This script will take a snapshot of zOSaaS volumes in /zaas1/techinfo/zVolumes
#
# This script should be placed into target image Ubuntu layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(pwd)
TASK_USERNAME=ibmsys1
PATH_ZIPPED=/zaas1/zimage/zVolumesZipped
PATH_BACKUP=/zaas1/zimage/zVolumesBackup
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
echo "[${SCRIPT_NAME}] creating zOSaaS snapshot ..."

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
echo "[${SCRIPT_NAME}] stopping zOSaaS service ..."
sudo systemctl stop zaasHelper.service

################################################################################
# zip Zowe pre-req volumes

# backup previous zipped volumes
echo "[${SCRIPT_NAME}] backup previous zipped volumes ..."
ZIPPED=$(ls -A "$PATH_ZIPPED")
if [ -z "$ZIPPED" ]; then
  echo "[${SCRIPT_NAME}] - no file to backup"
else
  TS=$(date +"%Y%m%d%H%M%S")
  mkdir -p "$PATH_BACKUP/$TS"
  echo "[${SCRIPT_NAME}] - backup to $PATH_BACKUP/$TS"
  mv $PATH_ZIPPED/* "$PATH_BACKUP/$TS"
fi

# get volume list
cd $PATH_UNZIPPED
UNZIPPED_VOLS=$(ls *)

# checksum
echo "[${SCRIPT_NAME}] generating md5sum ..."
md5sum -b * > zosaas_md5sums

# zip volumes
echo "[${SCRIPT_NAME}] zipping volumes from ${PATH_UNZIPPED} to ${PATH_ZIPPED} ..."
for x in $UNZIPPED_VOLS; do
  echo "  - $x"
  xn="${x}.gz"
  pigz --best --keep -c $x > $PATH_ZIPPED/$xn
done
echo "[${SCRIPT_NAME}] all volumes updated."

################################################################################
# restart the image
echo "[${SCRIPT_NAME}] starting zOSaaS ..."
sudo systemctl start zaasHelper.service

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
