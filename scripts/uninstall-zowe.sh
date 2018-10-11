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
# This script will uninstall Zowe
#
# This script should be placed into target image zOSaaS layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
DEFAULT_CI_ZOWE_ROOT_DIR=/zaas1/zowe
CI_ZOWE_ROOT_DIR=$DEFAULT_CI_ZOWE_ROOT_DIR
PROFILE=~/.profile
ZOWESVR_NAME=ZOWESVR

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

################################################################################
# parse parameters
function usage {
  echo "Uninstall Zowe."
  echo
  echo "Usage: $SCRIPT_NAME [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h  Display this help message."
  echo "  -t  Zowe installation folder. Optional, default is $DEFAULT_CI_ZOWE_ROOT_DIR."
  echo
}
while getopts ":ht:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    t)
      CI_ZOWE_ROOT_DIR=$OPTARG
      ;;
    \?)
      echo "[${SCRIPT_NAME}][error] invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "[${SCRIPT_NAME}][error] invalid option argument: -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

################################################################################
# essential validations
if [ ! -f "${CI_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh" ]; then
  echo "[${SCRIPT_NAME}][error] ${CI_ZOWE_ROOT_DIR} doesn't appear to have Zowe installed."
  exit 0
fi

################################################################################
echo "[${SCRIPT_NAME}] uninstall script started ..."
echo "[${SCRIPT_NAME}]   - Zowe folder : $CI_ZOWE_ROOT_DIR"
echo

# stop Zowe
echo "[${SCRIPT_NAME}] stopping Zowe ..."
(exec "${CI_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh")
echo

# removing environment viarables from .profile
echo "[${SCRIPT_NAME}] cleaning $PROFILE ..."
echo "[${SCRIPT_NAME}]   - before cleaning:"
cat "${PROFILE}"
echo "[${SCRIPT_NAME}]   -----------------"
echo
sed -E '/export +ZOWE_[^=]+=/d' "${PROFILE}" > "${PROFILE}.tmp" && mv "${PROFILE}.tmp" "${PROFILE}"
echo "[${SCRIPT_NAME}]   - after cleaning:"
cat "${PROFILE}"
echo "[${SCRIPT_NAME}]   -----------------"
echo

# listing ZOWE_ environment variables
echo "[${SCRIPT_NAME}] active ZOWE_* variables ..."
ENV_VARS=$(env | grep ZOWE_ | awk -F= '{print $1}')
for one in $ENV_VARS; do
  echo "[${SCRIPT_NAME}]   - $one"
done
echo

# removing ZOWESVR
echo "[${SCRIPT_NAME}] deleting ${ZOWESVR_NAME} PROC ..."
if [ ! -f "${CI_ZOWE_ROOT_DIR}/scripts/internal/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_ZOWESVR_AT=
procs=$("${CI_ZOWE_ROOT_DIR}/scripts/internal/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "${proclib}" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    if [ "${member}" = "${ZOWESVR_NAME}" ]; then
      FOUND_ZOWESVR_AT=$proclib
      break 2
    fi
  done
done
# do we find ZOWESVR?
if [ -z "$FOUND_ZOWESVR_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${ZOWESVR_NAME} in PROCLIBs, skipped."
else
  echo "[${SCRIPT_NAME}] found ${ZOWESVR_NAME} in ${FOUND_ZOWESVR_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_ZOWESVR_AT}(ZOWESVR)'" 10
fi
echo

# removing folder
echo "[${SCRIPT_NAME}] removing installation folder ..."
rm -fr $CI_ZOWE_ROOT_DIR || true

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
