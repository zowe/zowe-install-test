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
# This script will fix known issues after Zowe is started
#
# This script should be placed into target image zOSaaS layer to start.
################################################################################

SCRIPT_NAME=$(basename "$0")
CI_TEST_IMAGE_GUEST_SSH_HOST=$1
CI_USERNAME=$2
CI_PASSWORD=$3
echo "[${SCRIPT_NAME}] started ..."
if [ ! -f install-config.sh ]; then
  echo "[${SCRIPT_NAME}][error] cannot find install-config.sh"
  exit 1
fi
. install-config.sh
echo "[${SCRIPT_NAME}]    CIZT_ZOWE_ROOT_DIR           : $CIZT_ZOWE_ROOT_DIR"

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

################################################################################
# Run after install verify script
echo
RUN_SCRIPT=zowe-verify.sh
if [ -f "${CIZT_ZOWE_ROOT_DIR}/scripts/$RUN_SCRIPT" ]; then
  cd "${CIZT_ZOWE_ROOT_DIR}/scripts"
  run_script_with_timeout "${RUN_SCRIPT}" 1800
  EXIT_CODE=$?
  if [[ "$EXIT_CODE" != "0" ]]; then
    echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed with exit code ${EXIT_CODE}."
  else
    echo "[${SCRIPT_NAME}] ${RUN_SCRIPT} finished successfully."
  fi
fi
echo


################################################################################
# FIXME: zLux login may hang there which blocks UI test cases
# try a login to the zlux auth api
# curl -d "{\"username\":\"${CI_USERNAME}\",\"password\":\"${CI_PASSWORD}\"}" \
#      -H 'Content-Type: application/json' \
#      -X POST -k -i \
#      https://${CI_TEST_IMAGE_GUEST_SSH_HOST}:${CIZT_ZOWE_ZLUX_HTTPS_PORT}/auth

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
