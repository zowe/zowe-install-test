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
# This script will fix known issues after installing Zowe
#
# This script should be placed into target image zOSaaS layer to start.
# 
# FIXME: eventually this script should be empty
################################################################################

SCRIPT_NAME=$(basename "$0")
CI_HOSTNAME=$1
echo "[${SCRIPT_NAME}] started ..."
if [ -z "${CIZT_ZOWE_ROOT_DIR}" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find \$CIZT_ZOWE_ROOT_DIR"
  exit 1
fi
echo "[${SCRIPT_NAME}]    CI_HOSTNAME                : $CI_HOSTNAME"
echo "[${SCRIPT_NAME}]    CIZT_ZOWE_ROOT_DIR         : $CIZT_ZOWE_ROOT_DIR"

################################################################################
# Error when starting explore-server:
# [ERROR ] CWPKI0033E: The keystore located at safkeyringhybrid:///IZUKeyring.IZUDFLT did not load because of the following error: Errors encountered loading keyring. Keyring could not be loaded as a JCECCARACFKS or JCERACFKS keystore.
echo
echo "[${SCRIPT_NAME}] change ${CIZT_PROCLIB_MEMBER} RACF user ..."
(exec sh -c "tsocmd \"RDEFINE STARTED ${CIZT_PROCLIB_MEMBER}.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))\"")
(exec sh -c "tsocmd \"SETROPTS RACLIST(STARTED) REFRESH\"")
echo

################################################################################
# Error during zowe-install:
# Exporting certificate zOSMFCA from z/OSMF:
# keytool error (likely untranslated): java.io.FileNotFoundException: /zaas1/zowe-install/extracted/zowe-0.9.5/install/../temp_2018-12-19/zosmf_cert_zOSMFCA.cer (EDC5111I Permission denied.)
# FIXME: su doesn't work well here
# echo
# echo "[${SCRIPT_NAME}] import z/OSMF certificates which requires superuser permission ..."
# (exec sh -c "cd ${CIZT_ZOWE_ROOT_DIR}/api-mediation && su && export PATH=\$ZOWE_JAVA_HOME/bin:\$PATH && scripts/apiml_cm.sh --action trust-zosmf --zosmf-keyring IZUKeyring.IZUDFLT --zosmf-userid IZUSVR")
# echo

################################################################################
# explorer JES/MVS/USS has internal host name, convert to public domain
if [ -n "${CIZT_ZDNT_HOSTNAME}" ]; then
  echo "[${SCRIPT_NAME}] checking hostname ${CIZT_ZDNT_HOSTNAME} in explorer-* ..."
  FILES_TO_UPDATE="api_catalog jes_explorer mvs_explorer uss_explorer"
  for one in $FILES_TO_UPDATE; do
    ZDNT_FILE=$CIZT_ZOWE_ROOT_DIR/${one}/web/index.html
    echo "[${SCRIPT_NAME}]   - checking $ZDNT_FILE ..."
    if [ -f "$ZDNT_FILE" ]; then
      HAS_WRONG_HOSTNAME=$(grep $CIZT_ZDNT_HOSTNAME $ZDNT_FILE)
      if [ -n "$HAS_WRONG_HOSTNAME" ]; then
        sed "s#//${CIZT_ZDNT_HOSTNAME}:\([0-9]\+\)/#//${CI_HOSTNAME}:\1/#" $ZDNT_FILE > index.html.tmp
        mv index.html.tmp $ZDNT_FILE
        echo "[${SCRIPT_NAME}]     - updated."
      else
        echo "[${SCRIPT_NAME}]     - no need to update."
      fi
    else
      echo "[${SCRIPT_NAME}]     - doesn't exist."
    fi

    ZDNT_FILE=$CIZT_ZOWE_ROOT_DIR/${one}/server/configs/config.json
    echo "[${SCRIPT_NAME}]   - checking $ZDNT_FILE ..."
    if [ -f "$ZDNT_FILE" ]; then
      HAS_WRONG_HOSTNAME=$(grep $CIZT_ZDNT_HOSTNAME $ZDNT_FILE)
      if [ -n "$HAS_WRONG_HOSTNAME" ]; then
        sed "s#//${CIZT_ZDNT_HOSTNAME}:#//${CI_HOSTNAME}:#" $ZDNT_FILE > config.json.tmp
        mv config.json.tmp $ZDNT_FILE
        echo "[${SCRIPT_NAME}]     - updated."
      else
        echo "[${SCRIPT_NAME}]     - no need to update."
      fi
    else
      echo "[${SCRIPT_NAME}]     - doesn't exist."
    fi
  done
  echo
fi

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
