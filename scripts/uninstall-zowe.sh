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
# This script will uninstall Zowe
#
# This script should be placed into target image zOSaaS layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
KNOWN_ZOWE_JOB_NAMES="ZOWESVR ZOWESV1 ZOWE1SV"
PROFILE=~/.profile
ZOWE_PROFILE=~/.zowe_profile

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
  echo
}
while getopts ":h" opt; do
  case ${opt} in
    h)
      usage
      exit 0
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

################################################################################
echo "[${SCRIPT_NAME}] uninstall script started ..."
echo "[${SCRIPT_NAME}]   - Installation folder : $CIZT_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - Zowe folder         : $CIZT_ZOWE_ROOT_DIR"
echo

if [ ! -f "${CIZT_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi

################################################################################
# stop ZWESIS01
echo "[${SCRIPT_NAME}] stopping ZWESIS01 ..."
(exec "${CIZT_INSTALL_DIR}/opercmd" "P ${CIZT_ZSS_PROCLIB_MEMBER}")
echo

################################################################################
# stop Zowe
echo "[${SCRIPT_NAME}] stopping Zowe ..."
if [ -f "${CIZT_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh" ]; then
  (exec "${CIZT_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh")
fi
if [ -f "${CIZT_INSTALL_DIR}/opercmd" ]; then
  # job name before 1.4.0: ZOWESVR
  # job name after 1.4.0: ZOWESV1
  # job name preparing for 1.5.0: ZOWE1SV
  for ZOWE_JOB_NANE in $KNOWN_ZOWE_JOB_NAMES; do
    echo "[${SCRIPT_NAME}] - ${ZOWE_JOB_NANE}"
    (exec "${CIZT_INSTALL_DIR}/opercmd" "C ${ZOWE_JOB_NANE}")
  done
else
  echo "[${SCRIPT_NAME}][WARN] - cannot find opercmd, please make sure ${CIZT_PROCLIB_MEMBER} is stopped."
fi
echo

################################################################################
# delete started tasks
echo "[${SCRIPT_NAME}] deleting started tasks ..."
run_script_with_timeout "tsocmd 'RDELETE STARTED (ZWESIS*.*)'" 10
run_script_with_timeout "tsocmd 'RDELETE STARTED (ZOWESVR.*)'" 10
run_script_with_timeout "tsocmd 'SETR RACLIST(STARTED) REFRESH'" 10
echo

################################################################################
# removing environment viarables from .profile
touch "${PROFILE}"
echo "[${SCRIPT_NAME}] cleaning $PROFILE ..."
echo "[${SCRIPT_NAME}]   - before cleaning:"
cat "${PROFILE}"
echo "[${SCRIPT_NAME}]   -----------------"
echo
sed -E '/export +ZOWE_[^=]+=/d' "${PROFILE}" > "${PROFILE}.tmp" && mv -f "${PROFILE}.tmp" "${PROFILE}"
echo "[${SCRIPT_NAME}]   - after cleaning:"
cat "${PROFILE}"
echo "[${SCRIPT_NAME}]   -----------------"
echo

################################################################################
# listing ZOWE_ environment variables
echo "[${SCRIPT_NAME}] active ZOWE_* variables ..."
ENV_VARS=$(env | grep ZOWE_ | awk -F= '{print $1}')
for one in $ENV_VARS; do
  echo "[${SCRIPT_NAME}]   - $one"
done
echo

################################################################################
# delete .zowe_profile
echo "[${SCRIPT_NAME}] deleting $ZOWE_PROFILE ..."
rm -fr "${ZOWE_PROFILE}"
echo

################################################################################
# removing ZOWESVR
echo "[${SCRIPT_NAME}] deleting ${CIZT_PROCLIB_MEMBER} PROC ..."
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_ZOWESVR_AT=
procs=$("${CIZT_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "${proclib}" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    if [ "${member}" = "${CIZT_PROCLIB_MEMBER}" ]; then
      FOUND_ZOWESVR_AT=$proclib
      break 2
    fi
  done
done
# do we find ZOWESVR?
if [ -z "$FOUND_ZOWESVR_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_PROCLIB_MEMBER} in PROCLIBs, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CIZT_PROCLIB_MEMBER} in ${FOUND_ZOWESVR_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_ZOWESVR_AT}(${CIZT_PROCLIB_MEMBER})'" 10
fi
echo

################################################################################
# delet APF settings for LOADLIB
echo "[${SCRIPT_NAME}] deleting APF settings of ${CIZT_ZSS_LOADLIB_DS_NAME}(${CIZT_ZSS_LOADLIB_MEMBER}) ..."
XMEM_LOADLIB_VOLUME=$(${CIZT_INSTALL_DIR}/opercmd "D PROG,APF,DSNAME=${CIZT_ZSS_LOADLIB_DS_NAME}" | grep -e "[0-9]\\+ \\+[a-z0-9A-Z]\\+ \\+${CIZT_ZSS_LOADLIB_DS_NAME}" | awk "{print \$2}")
if [ -z "$XMEM_LOADLIB_VOLUME" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find volume of ${CIZT_ZSS_LOADLIB_DS_NAME}, skipped."
else
  echo "[${SCRIPT_NAME}] found volume of ${CIZT_ZSS_LOADLIB_DS_NAME} is ${XMEM_LOADLIB_VOLUME}, deleting APF settings ..."
  if [ "$XMEM_LOADLIB_VOLUME" = "SMS" ]; then
    (exec "${CIZT_INSTALL_DIR}/opercmd" "SETPROG APF,DELETE,DSNAME=${CIZT_ZSS_LOADLIB_DS_NAME},${XMEM_LOADLIB_VOLUME}")
  else
    (exec "${CIZT_INSTALL_DIR}/opercmd" "SETPROG APF,DELETE,DSNAME=${CIZT_ZSS_LOADLIB_DS_NAME},VOLUME=${XMEM_LOADLIB_VOLUME}")
  fi
fi
echo

################################################################################
# removing xmem LOADLIB(ZWESIS01)
echo "[${SCRIPT_NAME}] deleting ${CIZT_ZSS_LOADLIB_DS_NAME}(${CIZT_ZSS_LOADLIB_MEMBER}) ..."
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CIZT_ZSS_LOADLIB_DS_NAME} ..."
members=$(tsocmd listds "${CIZT_ZSS_LOADLIB_DS_NAME}" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  if [ "${member}" = "${CIZT_ZSS_LOADLIB_MEMBER}" ]; then
    FOUND_DS_MEMBER_AT=$CIZT_ZSS_LOADLIB_DS_NAME
    break 2
  fi
done
# do we find CIZT_ZSS_LOADLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_ZSS_LOADLIB_MEMBER} in ${CIZT_ZSS_LOADLIB_DS_NAME}, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CIZT_ZSS_LOADLIB_MEMBER} in ${FOUND_DS_MEMBER_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}(${CIZT_ZSS_LOADLIB_MEMBER})'" 10
fi
echo

################################################################################
# removing xmem PARMLIB(ZWESIP00)
echo "[${SCRIPT_NAME}] deleting ${CIZT_ZSS_PARMLIB_DS_NAME}(${CIZT_ZSS_PARMLIB_MEMBER}) ..."
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CIZT_ZSS_PARMLIB_DS_NAME} ..."
members=$(tsocmd listds "${CIZT_ZSS_PARMLIB_DS_NAME}" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  if [ "${member}" = "${CIZT_ZSS_PARMLIB_MEMBER}" ]; then
    FOUND_DS_MEMBER_AT=$CIZT_ZSS_PARMLIB_DS_NAME
    break 2
  fi
done
# do we find CIZT_ZSS_PARMLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_ZSS_PARMLIB_MEMBER} in ${CIZT_ZSS_PARMLIB_DS_NAME}, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CIZT_ZSS_PARMLIB_MEMBER} in ${FOUND_DS_MEMBER_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}(${CIZT_ZSS_PARMLIB_MEMBER})'" 10
fi
echo

################################################################################
# removing ZWESIS01
echo "[${SCRIPT_NAME}] deleting ${CIZT_ZSS_PROCLIB_MEMBER} PROC ..."
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_ZWESIS01_AT=
procs=$("${CIZT_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "${proclib}" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    if [ "${member}" = "${CIZT_ZSS_PROCLIB_MEMBER}" ]; then
      FOUND_ZWESIS01_AT=$proclib
      break 2
    fi
  done
done
# do we find ZWESIS01?
if [ -z "$FOUND_ZWESIS01_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_ZSS_PROCLIB_MEMBER} in PROCLIBs, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CIZT_ZSS_PROCLIB_MEMBER} in ${FOUND_ZWESIS01_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_ZWESIS01_AT}(${CIZT_ZSS_PROCLIB_MEMBER})'" 10
fi
echo

################################################################################
# removing folder
echo "[${SCRIPT_NAME}] removing installation folder ..."
(echo rm -fr $CIZT_ZOWE_ROOT_DIR | su) || true

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
