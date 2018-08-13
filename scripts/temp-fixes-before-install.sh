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
CI_ZOSMF_URL=$3
echo "[${SCRIPT_NAME}] started ..."
echo "[${SCRIPT_NAME}]        z/OSMF URL: $CI_ZOSMF_URL"
CI_PWD=$(pwd)

################################################################################
# remove unused files to free more space
echo "[${SCRIPT_NAME}] removing unused files ..."
rm /u/tstradm/python-2017-04-12-py27.tar.gz || true
rm /zaas1/tmp/* || true
rm /zaas1/ported/tmp/python-2017-04-12-py27.tar.gz || true

################################################################################
# FIX for 0.8.3, missing ~/.profile
# install script error message:
# .: /zaas1/zowe-install/install/..//scripts/zowe-init.sh 36: .: /zaas1/zowe-install/install/zowe-install.sh 32: /u/tstradm/.profile: not found
SHELL_PROFILE=/u/tstradm/.profile
if [ -f "$SHELL_PROFILE" ]; then
  echo "[${SCRIPT_NAME}] $SHELL_PROFILE already exists."
else
  echo "[${SCRIPT_NAME}] $SHELL_PROFILE is missing, try to add."
  touch $SHELL_PROFILE
fi

################################################################################
# Fix z/OSMF corrupted ltpa file
#
# Error message when login to z/OSMF
# [ERROR   ] CWWKS4106E: LTPA configuration error. Unable to create or read LTPA key file: /var/zosmf/configuration/servers/zosmfServer/resources/security/ltpa.keys
# [ERROR   ] CWWKS4000E: A configuration exception has occurred. The requested TokenService instance of type Ltpa2 could not be found.
# Fix by removing ltpa key file and restart z/OSMF
#
# TODO:
# Error when try login to zLux: Authentication failed for 1 types. Types: ["zss"]
# Fix by: Add "127.0.0.1 localhost" to ADCD.Z23A.TCPPARMS(GBLIPNOD)
if [ ! -f "$FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd" ]; then
  echo "[${SCRIPT_NAME}] opercmd doesn't exist."
  exit 1;
fi
if [ ! -x "$FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd" ]; then
  chmod +x "$FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd"
fi
echo "[${SCRIPT_NAME}] stopping IZUSVR1 ..."
($FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd "C IZUSVR1") || exit 1
sleep 15
echo "[${SCRIPT_NAME}] stopping IZUANG1 ..."
($FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd "C IZUANG1") || exit 1
sleep 10
echo "[${SCRIPT_NAME}] delete /var/zosmf/configuration/servers/zosmfServer/resources/security/ltpa.keys ..."
rm /var/zosmf/configuration/servers/zosmfServer/resources/security/ltpa.keys || true
echo "[${SCRIPT_NAME}] starting IZUANG1 ..."
($FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd "S IZUANG1") || exit 1
sleep 10
echo "[${SCRIPT_NAME}] starting IZUSVR1 ..."
($FULL_EXTRACTED_ZOWE_FOLDER/scripts/opercmd "S IZUSVR1") || exit 1
sleep 20

if [ -n "$CI_ZOSMF_URL" ]; then
  echo "[${SCRIPT_NAME}] FIXME: we don't have tool to check if $CI_ZOSMF_URL is ready."
fi

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
