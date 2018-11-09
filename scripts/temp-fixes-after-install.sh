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
CI_HOSTNAME=$2
echo "[${SCRIPT_NAME}] started ..."
echo "[${SCRIPT_NAME}]    CI_ZOWE_ROOT_DIR           : $CI_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]    CI_HOSTNAME                : $CI_HOSTNAME"

################################################################################
# Error when starting explore-server:
# [ERROR ] CWPKI0033E: The keystore located at safkeyringhybrid:///IZUKeyring.IZUDFLT did not load because of the following error: Errors encountered loading keyring. Keyring could not be loaded as a JCECCARACFKS or JCERACFKS keystore.
echo
echo "[${SCRIPT_NAME}] change ZOWESVR RACF user ..."
(exec sh -c 'tsocmd "RDEFINE STARTED ZOWESVR.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))"')
(exec sh -c 'tsocmd "SETROPTS RACLIST(STARTED) REFRESH"')
echo

################################################################################
# Error when starting explore-server:
# without ZOSMF_HOST, explorer-server will get connection refused error on 
echo
echo "[${SCRIPT_NAME}] validating explorer server server.env ..."
cd "${CI_ZOWE_ROOT_DIR}/explorer-server/wlp/usr/servers/Atlas"
iconv -f IBM-850 -t IBM-1047 server.env > server.env.1047
echo "[${SCRIPT_NAME}] current server.env:"
cat server.env.1047
HAS_ZOSMF_HOST=$(cat server.env.1047 | grep 'ZOSMF_HOST=')
if [ -z "$HAS_ZOSMF_HOST" ]; then
  echo "[${SCRIPT_NAME}] need to add ZOSMF_HOST"
  echo "" >> server.env.1047
  echo "ZOSMF_HOST=10.1.1.2" >> server.env.1047
  echo "[${SCRIPT_NAME}] updated server.env:"
  cat server.env.1047
  iconv -f IBM-1047 -t IBM-850 server.env.1047 > server.env
else
  echo "[${SCRIPT_NAME}] ZOSMF_HOST is set, no need to fix."
fi
rm server.env.1047

################################################################################
# explorer JES/MVS/USS has internal host name, convert to public domain
echo
echo "[${SCRIPT_NAME}] checking hostname in explorer-* ..."
ZDNT_HOSTNAME=S0W1
FILES_TO_UPDATE="explorer-JES explorer-USS explorer-MVS api_catalog"
for one in $FILES_TO_UPDATE; do
  ZDNT_FILE=$CI_ZOWE_ROOT_DIR/${one}/web/index.html
  echo "[${SCRIPT_NAME}]   - checking $ZDNT_FILE ..."
  HAS_WRONG_HOSTNAME=$(grep $ZDNT_HOSTNAME $ZDNT_FILE)
  if [ -n "$HAS_WRONG_HOSTNAME" ]; then
    sed "s#//${ZDNT_HOSTNAME}:\([0-9]\+\)/#//${CI_HOSTNAME}:\1/#" $ZDNT_FILE > index.html.tmp
    mv index.html.tmp $ZDNT_FILE
    echo "[${SCRIPT_NAME}]     - updated."
  else
    echo "[${SCRIPT_NAME}]     - no need to update."
  fi
done

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
