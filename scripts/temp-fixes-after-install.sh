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
# This script will fix known issues after installing Zowe
#
# This script should be placed into target image zOSaaS layer to start.
# 
# FIXME: eventually this script should be empty
################################################################################

SCRIPT_NAME=$(basename "$0")
CI_ZOWE_ROOT_DIR=$1
echo "[${SCRIPT_NAME}] started ..."

################################################################################
# Error when starting explore-server:
# [ERROR ] CWPKI0033E: The keystore located at safkeyringhybrid:///IZUKeyring.IZUDFLT did not load because of the following error: Errors encountered loading keyring. Keyring could not be loaded as a JCECCARACFKS or JCERACFKS keystore.
(exec sh -c 'tsocmd "RDEFINE STARTED ZOWESVR.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))"')
(exec sh -c 'tsocmd "SETROPTS RACLIST(STARTED) REFRESH"')

################################################################################
# Error when starting explore-server:
# CWWKB0234E JAVA_HOME location  does not exist
# CWWKB0210E Failed to resolve JAVA_HOME
cd "${CI_ZOWE_ROOT_DIR}/explorer-server/wlp/usr/servers/Atlas"
CURRENT_SERVER_ENV=$(iconv -f IBM-850 -t IBM-1047 server.env)
if [ "$CURRENT_SERVER_ENV" = "JAVA_HOME=" ]; then
  echo "[${SCRIPT_NAME}] current server.env: $CURRENT_SERVER_ENV"
  echo "[${SCRIPT_NAME}] need to fix"
  echo "JAVA_HOME=/usr/lpp/java/J8.0_64" > server.env.1047
  iconv -f IBM-1047 -t IBM-850 server.env.1047 > server.env
  rm server.env.1047
else
  echo "[${SCRIPT_NAME}] current server.env: $CURRENT_SERVER_ENV"
  echo "[${SCRIPT_NAME}] JAVA_HOME is set properly, no need to fix."
fi

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
