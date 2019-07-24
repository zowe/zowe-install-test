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
DEFAULT_CI_ZOWE_ROOT_DIR=/zaas1/zowe
DEFAULT_CI_INSTALL_DIR=/zaas1/zowe-install
DEFAULT_CI_ZOWE_DS_MEMBER=ZOWESVR
CI_ZOWE_ROOT_DIR=$DEFAULT_CI_ZOWE_ROOT_DIR
CI_INSTALL_DIR=$DEFAULT_CI_INSTALL_DIR
PROFILE=~/.profile
ZOWE_PROFILE=~/.zowe_profile
CI_ZOWE_DS_MEMBER=$DEFAULT_CI_ZOWE_DS_MEMBER
# FIXME: these are hardcoded
CI_XMEM_PROCLIB_MEMBER=ZWESIS01
CI_XMEM_PARMLIB=IZUSVR.PARMLIB
CI_XMEM_PARMLIB_MEMBER=ZWESIP00
CI_XMEM_LOADLIB=IZUSVR.LOADLIB
CI_XMEM_LOADLIB_MEMBER=ZWESIS01

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
  echo "  -i  Zowe install working folder. Optional, default is $DEFAULT_CI_INSTALL_DIR."
  echo "  -t  Zowe target folder. Optional, default is $DEFAULT_CI_ZOWE_ROOT_DIR."
  echo "  -m  Zowe PROCLIB data set member name. Optional, default is $DEFAULT_CI_ZOWE_DS_MEMBER."
  echo
}
while getopts ":hi:t:m:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    i)
      CI_INSTALL_DIR=$OPTARG
      ;;
    t)
      CI_ZOWE_ROOT_DIR=$OPTARG
      ;;
    m)
      CI_ZOWE_DS_MEMBER=$OPTARG
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
echo "[${SCRIPT_NAME}]   - Installation folder : $CI_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - Zowe folder         : $CI_ZOWE_ROOT_DIR"
echo

# stop ZWESIS01
echo "[${SCRIPT_NAME}] stopping ZWESIS01 ..."
if [ -f "${CI_INSTALL_DIR}/opercmd" ]; then
  (exec "${CI_INSTALL_DIR}/opercmd" "P ${CI_XMEM_PROCLIB_MEMBER}")
else
  echo "[${SCRIPT_NAME}][WARN] - cannot find opercmd, please make sure ${CI_XMEM_PROCLIB_MEMBER} is stopped."
fi
echo

# stop Zowe
echo "[${SCRIPT_NAME}] stopping Zowe ..."
if [ -f "${CI_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh" ]; then
  (exec "${CI_ZOWE_ROOT_DIR}/scripts/zowe-stop.sh")
elif [ -f "${CI_INSTALL_DIR}/opercmd" ]; then
  (exec "${CI_INSTALL_DIR}/opercmd" "C ${CI_ZOWE_DS_MEMBER}")
else
  echo "[${SCRIPT_NAME}][WARN] - cannot find opercmd, please make sure ${CI_ZOWE_DS_MEMBER} is stopped."
fi
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

# delete .zowe_profile
echo "[${SCRIPT_NAME}] deleting $ZOWE_PROFILE ..."
rm -fr "${ZOWE_PROFILE}"
echo

# removing ZOWESVR
echo "[${SCRIPT_NAME}] deleting ${CI_ZOWE_DS_MEMBER} PROC ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_ZOWESVR_AT=
procs=$("${CI_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "${proclib}" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    if [ "${member}" = "${CI_ZOWE_DS_MEMBER}" ]; then
      FOUND_ZOWESVR_AT=$proclib
      break 2
    fi
  done
done
# do we find ZOWESVR?
if [ -z "$FOUND_ZOWESVR_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CI_ZOWE_DS_MEMBER} in PROCLIBs, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CI_ZOWE_DS_MEMBER} in ${FOUND_ZOWESVR_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_ZOWESVR_AT}(${CI_ZOWE_DS_MEMBER})'" 10
fi
echo

# delet APF settings for LOADLIB
echo "[${SCRIPT_NAME}] deleting APF settings of ${CI_XMEM_LOADLIB}(${CI_XMEM_LOADLIB_MEMBER}) ..."
XMEM_LOADLIB_VOLUME=$(${CI_INSTALL_DIR}/opercmd "D PROG,APF,DSNAME=${CI_XMEM_LOADLIB}" | grep -e "[0-9]\\+ \\+[a-z0-9A-Z]\\+ \\+${CI_XMEM_LOADLIB}" | awk "{print \$2}")
if [ -z "$XMEM_LOADLIB_VOLUME" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find volume of ${CI_XMEM_LOADLIB}, skipped."
else
  echo "[${SCRIPT_NAME}] found volume of ${CI_XMEM_LOADLIB} is ${XMEM_LOADLIB_VOLUME}, deleting APF settings ..."
  if [ "$XMEM_LOADLIB_VOLUME" = "SMS" ]; then
    ${CI_INSTALL_DIR}/opercmd "SETPROG APF,DELETE,DSNAME=${CI_XMEM_LOADLIB},${XMEM_LOADLIB_VOLUME}"
  else
    ${CI_INSTALL_DIR}/opercmd "SETPROG APF,DELETE,DSNAME=${CI_XMEM_LOADLIB},VOLUME=${XMEM_LOADLIB_VOLUME}"
  fi
fi
echo

# removing xmem LOADLIB(ZWESIS01)
echo "[${SCRIPT_NAME}] deleting ${CI_XMEM_LOADLIB}(${CI_XMEM_LOADLIB_MEMBER}) ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CI_XMEM_LOADLIB} ..."
members=$(tsocmd listds "${CI_XMEM_LOADLIB}" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  if [ "${member}" = "${CI_XMEM_LOADLIB_MEMBER}" ]; then
    FOUND_DS_MEMBER_AT=$CI_XMEM_LOADLIB
    break 2
  fi
done
# do we find CI_XMEM_LOADLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CI_XMEM_LOADLIB_MEMBER} in ${CI_XMEM_LOADLIB}, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CI_XMEM_LOADLIB_MEMBER} in ${FOUND_DS_MEMBER_AT}, deleting ..."
  # run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}(${CI_XMEM_LOADLIB_MEMBER})'" 10
  run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}'" 10
fi
echo

# removing xmem PARMLIB(ZWESIP00)
echo "[${SCRIPT_NAME}] deleting ${CI_XMEM_PARMLIB}(${CI_XMEM_PARMLIB_MEMBER}) ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CI_XMEM_PARMLIB} ..."
members=$(tsocmd listds "${CI_XMEM_PARMLIB}" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  if [ "${member}" = "${CI_XMEM_PARMLIB_MEMBER}" ]; then
    FOUND_DS_MEMBER_AT=$CI_XMEM_PARMLIB
    break 2
  fi
done
# do we find CI_XMEM_PARMLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CI_XMEM_PARMLIB_MEMBER} in ${CI_XMEM_PARMLIB}, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CI_XMEM_PARMLIB_MEMBER} in ${FOUND_DS_MEMBER_AT}, deleting ..."
  # run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}(${CI_XMEM_PARMLIB_MEMBER})'" 10
  run_script_with_timeout "tsocmd DELETE '${FOUND_DS_MEMBER_AT}'" 10
fi
echo

# removing ZWESIS01
echo "[${SCRIPT_NAME}] deleting ${CI_XMEM_PROCLIB_MEMBER} PROC ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# make sure profile noprefix
export TSOPROFILE="noprefix"
tsocmd profile noprefix
# listing all proclibs and members
FOUND_ZWESIS01_AT=
procs=$("${CI_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "${proclib}" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    if [ "${member}" = "${CI_XMEM_PROCLIB_MEMBER}" ]; then
      FOUND_ZWESIS01_AT=$proclib
      break 2
    fi
  done
done
# do we find ZWESIS01?
if [ -z "$FOUND_ZWESIS01_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CI_XMEM_PROCLIB_MEMBER} in PROCLIBs, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CI_XMEM_PROCLIB_MEMBER} in ${FOUND_ZWESIS01_AT}, deleting ..."
  run_script_with_timeout "tsocmd DELETE '${FOUND_ZWESIS01_AT}(${CI_XMEM_PROCLIB_MEMBER})'" 10
fi
echo

# removing folder
echo "[${SCRIPT_NAME}] removing installation folder ..."
rm -fr $CI_ZOWE_ROOT_DIR || true

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
