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
# This script will install Zowe Cross Memory Server
#
# This script should be run from the folder where zowe-install-apf-server.yaml
# located.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
CI_ZSS_CONFIG_FILE=zowe-install-apf-server.yaml

# FIXME: these values should be configurable, now it's hardcoded for zD&T
CI_ZSS_PROCLIB_DS_NAME=USER.Z23B.PROCLIB
CI_ZSS_PARMLIB_DS_NAME=IZUSVR.PARMLIB
CI_ZSS_LOADLIB_DS_NAME=IZUSVR.LOADLIB
CI_ZSS_ZOWE_USER=IZUSVR
CI_ZSS_STC_USER_ID=990010
CI_ZSS_STC_GROUP=IZUADMIN
CI_ZSS_STC_USER=IZUSVR

if [ ! -f "${CI_ZSS_CONFIG_FILE}" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find ${CI_ZSS_CONFIG_FILE} in $(pwd)."
  echo
  exit 1
fi

# allow to exit by ctrl+c
function finish {
  echo "[${SCRIPT_NAME}] interrupted"
  exit 1
}
trap finish SIGINT

################################################################################
# Kill process and all children processes
# 
# Arguments:
#   $1        Process ID
################################################################################
function kill_all_childen {
  TO_KILL_PID=$1

  ALL_CHILDREN=
  CHILDREN=$TO_KILL_PID
  while [ -n "$CHILDREN" ]; do
    ALL_CHILDREN="$ALL_CHILDREN $CHILDREN"

    SUB_CHILDREN=
    for one in $CHILDREN; do
      ONE_SUB_CHILDREN=$(ps -o pid,ppid | grep "[0-9]\+[ ]\+$one" | awk '{print $1}')
      if [ -n "$ONE_SUB_CHILDREN" ]; then
  SUB_CHILDREN="$SUB_CHILDREN $ONE_SUB_CHILDREN"
      fi
    done
    CHILDREN=$SUB_CHILDREN
  done
  echo "[kill_all_childen] process $TO_KILL_PID has children: $ALL_CHILDREN, killing all."
  kill -9 $ALL_CHILDREN || true
}

################################################################################
# Run a script with a timeout
# 
# Arguments:
#   $1        Script path
#   $2        Timeout format supported by "sleep". Example:
#             - 60      60 seconds
#             - 2m      2 minutes
#
# Returns:
#   exit code
################################################################################
function run_script_with_timeout {
  SCRIPT_TO_RUN=$1
  TIMEOUT=$2

  echo
  echo "################################################################################"

  TMP_LOG_FILE="$$-$RANDOM.log"
  (exec sh -c "$SCRIPT_TO_RUN" > $TMP_LOG_FILE) & CMD_PID=$!
  echo "[run_script_with_timeout] '${SCRIPT_TO_RUN}' process ID is $CMD_PID"
  # start waiter process in background
  (sleep $TIMEOUT && kill -9 $CMD_PID) & WAITER_PID=$!
  # wait for process to exit
  wait $CMD_PID
  EXIT_CODE=$?

  # check if waiter process is still there
  WAITER_EXISTENCE=$(ps -o pid | grep $WAITER_PID)
  if [ -n "$WAITER_EXISTENCE" ]; then
    # waiter process is still there, process exit by itself
    kill_all_childen $WAITER_PID
  else
    # waiter process is gone, means process if killed after timeout
    EXIT_CODE=9999
  fi

  echo "[run_script_with_timeout] '${SCRIPT_TO_RUN}' exit: $EXIT_CODE"

  # show log if exists
  if [ -f "$TMP_LOG_FILE" ]; then
    if [ -s "$TMP_LOG_FILE" ]; then
      echo "[run_script_with_timeout] stdout log >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
      cat $TMP_LOG_FILE || true
      echo "[run_script_with_timeout] log end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    fi
    rm $TMP_LOG_FILE
  fi
  echo

  return $EXIT_CODE
}

# configure installation
echo "[${SCRIPT_NAME}] configure installation yaml ..."
cat "${CI_ZSS_CONFIG_FILE}" | \
  sed -e "/^install:/,\$s#proclib=.*\$#proclib=${CI_ZSS_PROCLIB_DS_NAME}#" | \
  sed -e "/^install:/,\$s#parmlib=.*\$#parmlib=${CI_ZSS_PARMLIB_DS_NAME}#" | \
  sed -e "/^install:/,\$s#loadlib=.*\$#loadlib=${CI_ZSS_LOADLIB_DS_NAME}#" | \
  sed -e "/^users:/,\$s#zoweUser=.*\$#zoweUser=${CI_ZSS_ZOWE_USER}#" | \
  sed -e "/^users:/,\$s#stcUserUid=.*\$#stcUserUid=${CI_ZSS_STC_USER_ID}#" | \
  sed -e "/^users:/,\$s#stcGroup=.*\$#stcGroup=${CI_ZSS_STC_GROUP}#" | \
  sed -e "/^users:/,\$s#stcUser=.*\$#stcUser=${CI_ZSS_STC_USER}#" > "${CI_ZSS_CONFIG_FILE}.tmp"
mv "${CI_ZSS_CONFIG_FILE}.tmp" "${CI_ZSS_CONFIG_FILE}"
echo "[${SCRIPT_NAME}] current ZSS configuration is:"
cat "${CI_ZSS_CONFIG_FILE}"

# start ZSS installation
echo "[${SCRIPT_NAME}] start ZSS installation ..."
# FIXME: zowe-install-apf-server.sh should exit by itself, not depends on timeout
RUN_SCRIPT=zowe-install-apf-server.sh
run_script_with_timeout $RUN_SCRIPT 1800
EXIT_CODE=$?
if [[ "$EXIT_CODE" != "0" ]]; then
  echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
  echo
  exit 1
else
  echo "[${SCRIPT_NAME}] ${RUN_SCRIPT} succeeds."
  echo
fi
echo

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
