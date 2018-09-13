#!/bin/bash -e

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
# This script will reset zOSaaS volumes to /zaas1/techinfo/zVolumesZipped
# 
# This script should be placed into target image Ubuntu layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(pwd)
TASK_USERNAME=ibmsys1
PATH_ZIPPED=/zaas1/techinfo/zVolumesZipped
PATH_UNZIPPED=/zaas1/zVolumes

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
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" == "river" ]]; then
  PATH_ZIPPED=/zaas1/techinfo/zVolumesZipped/prereqs/techinfo/zVolumesZipped
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

  echo "[${SCRIPT_NAME}] killing other processes started by onboot.sh"
  ONBOOT_PID=$(ps -ef -o pid,comm | grep onboot.sh | grep -v grep | awk '{print $1}')
  if [ -n "$ONBOOT_PID" ]; then
    echo "[${SCRIPT_NAME}]     - killing process group of onboot.sh PID=$ONBOOT_PID"
    kill -- -$ONBOOT_PID
  else
    echo "[${SCRIPT_NAME}]     - cannot find process group of onboot.sh"
  fi
  echo "[${SCRIPT_NAME}]     - killing x3270 processes..."
  pkill -9 -x x3270
  echo "[${SCRIPT_NAME}]     - done."
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
  (exec bash -c temp-fixes-prereqs-image.sh)
fi

################################################################################
# restart the image
# FIXME: we cannot simply restart image to bring up zD&T, waiting for v4
# echo "[${SCRIPT_NAME}] rebooting image ..."
# sudo shutdown -r 1
# echo "[${SCRIPT_NAME}] please manually start zD&T..."
# echo
# echo "[${SCRIPT_NAME}] to manually start, please follow these steps:"
# echo "[${SCRIPT_NAME}] 1. start SSH tunnel on VNC port 5901"
# echo "[${SCRIPT_NAME}]    $ ssh -L 5901:localhost:5901 ibmsys1@river.zowe.org"
# echo "[${SCRIPT_NAME}] 2. use vncviewer or other tools (like screen sharing) to connect to vnc"
# echo "[${SCRIPT_NAME}]    $ vncviewer localhost:1"
# echo "[${SCRIPT_NAME}] 3. from VNC Terminal command line, run command:"
# echo "[${SCRIPT_NAME}]    $ /zaas1/scripts/onboot.sh"
# echo "[${SCRIPT_NAME}] 4. go back to Jenkins job and click Continue."
echo "[${SCRIPT_NAME}] restarting VNC to start onboot.sh ..."
sudo systemctl restart vncserver.service

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
