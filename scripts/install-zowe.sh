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
# This script will install Zowe
#
# This script should be placed into target image zOSaaS layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
DEFAULT_CI_ZOWE_ROOT_DIR=/zaas1/zowe
DEFAULT_CI_INSTALL_DIR=/zaas1/zowe-install
CI_ZOWE_CONFIG_FILE=zowe-install.yaml
CI_ZOWE_PAX=
CI_SKIP_TEMP_FIXES=no
CI_UNINSTALL=no
CI_ZOSMF_URL=
CI_ZOWE_ROOT_DIR=$DEFAULT_CI_ZOWE_ROOT_DIR
CI_INSTALL_DIR=$DEFAULT_CI_INSTALL_DIR

# allow to exit by ctrl+c
function finish {
  echo "[${SCRIPT_NAME}] interrupted"
  exit 1
}
trap finish SIGINT

################################################################################
# Set up timeout check for a process
#
# NOTE: This function will also add execution permission to the script.
#
# Arguments:
#   $1        Scipt path
#   $2        From encoding. Optional, default is ISO8859-1
#   $3        To encoding. Optional, default is IBM-1047
################################################################################
function ensure_script_encoding {
  SCRIPT_TO_CHECK=$1
  FROM_ENCODING=$2
  TO_ENCODING=$3

  if [ -z "$FROM_ENCODING"]; then
    FROM_ENCODING=ISO8859-1
  fi
  if [ -z "$TO_ENCODING"]; then
    TO_ENCODING=IBM-1047
  fi

  iconv -f $FROM_ENCODING -t $TO_ENCODING "${SCRIPT_TO_CHECK}" > "${SCRIPT_TO_CHECK}.new"
  mv "${SCRIPT_TO_CHECK}.new" "${SCRIPT_TO_CHECK}" && chmod +x "${SCRIPT_TO_CHECK}"
}

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
  echo "Extract and install Zowe."
  echo
  echo "Usage: $SCRIPT_NAME [OPTIONS] package"
  echo
  echo "Options:"
  echo "  -h  Display this help message."
  echo "  -s  If skip the temporary fixes before and after installation. Optional, default is no."
  echo "  -u  If uninstall Zowe first. Optional, default is no."
  echo "  -m  z/OSMF URL for testing."
  echo "  -t  Installation target folder. Optional, default is $DEFAULT_CI_ZOWE_ROOT_DIR."
  echo "  -i  Installation working folder. Optional, default is $DEFAULT_CI_INSTALL_DIR."
  echo
}
while getopts ":hsum:t:i:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    s)
      CI_SKIP_TEMP_FIXES=yes
      ;;
    u)
      CI_UNINSTALL=yes
      ;;
    m)
      CI_ZOSMF_URL=$OPTARG
      ;;
    t)
      CI_ZOWE_ROOT_DIR=$OPTARG
      ;;
    i)
      CI_INSTALL_DIR=$OPTARG
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
shift $((OPTIND-1))
CI_ZOWE_PAX=$1

################################################################################
# essential validations
if [ -z "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] package is required."
  exit 1
fi
if [ ! -f "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find the package file."
  exit 1
fi
# convert encoding if those files uploaded
cd $CI_INSTALL_DIR
if [ -f "temp-fixes-after-install.sh" ]; then
  ensure_script_encoding temp-fixes-after-install.sh
fi
if [ -f "temp-fixes-before-install.sh" ]; then
  ensure_script_encoding temp-fixes-before-install.sh
fi
if [ -f "uninstall-zowe.sh" ]; then
  ensure_script_encoding uninstall-zowe.sh
fi

################################################################################
echo "[${SCRIPT_NAME}] installation script started ..."
echo "[${SCRIPT_NAME}]   - package file        : $CI_ZOWE_PAX"
echo "[${SCRIPT_NAME}]   - installation target : $CI_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]   - temporary folder    : $CI_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - skip temp files     : $CI_SKIP_TEMP_FIXES"
echo "[${SCRIPT_NAME}]   - uninstall previo    : $CI_UNINSTALL"
echo

if [[ "$CI_UNINSTALL" = "yes" ]]; then
  cd $CI_INSTALL_DIR
  RUN_SCRIPT=uninstall-zowe.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT}" 300
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
      exit 1
    fi
  fi
fi

# extract Zowe
echo "[${SCRIPT_NAME}] extracting $CI_ZOWE_PAX to $CI_INSTALL_DIR/extracted ..."
mkdir -p $CI_INSTALL_DIR/extracted
cd $CI_INSTALL_DIR/extracted
rm -fr *
pax -ppx -rf $CI_ZOWE_PAX
EXIT_CODE=$?
if [[ "$EXIT_CODE" == "0" ]]; then
  echo "[${SCRIPT_NAME}] $CI_ZOWE_PAX extracted."
else
  echo "[${SCRIPT_NAME}][error] start Zowe failed."
  exit 1
fi
echo

# check extracted folder
# - old version will have several folders like files, install, licenses, scripts, etc
# - new version will only have one folder of zowe-{version}
FULL_EXTRACTED_ZOWE_FOLDER=$CI_INSTALL_DIR/extracted
EXTRACTED_FILES=$(ls -1 $CI_INSTALL_DIR/extracted | wc -l | awk '{print $1}')
HAS_EXTRA_ZOWE_FOLDER=0
if [ "$EXTRACTED_FILES" = "1" ]; then
  HAS_EXTRA_ZOWE_FOLDER=1
  EXTRACTED_ZOWE_FOLDER=$(ls -1 $CI_INSTALL_DIR/extracted)
  FULL_EXTRACTED_ZOWE_FOLDER=$CI_INSTALL_DIR/extracted/$EXTRACTED_ZOWE_FOLDER
fi

# configure installation
echo "[${SCRIPT_NAME}] configure installation yaml ..."
cd $FULL_EXTRACTED_ZOWE_FOLDER/install
sed "s#rootDir=.\+\$#rootDir=$CI_ZOWE_ROOT_DIR#" "${CI_ZOWE_CONFIG_FILE}" > "${CI_ZOWE_CONFIG_FILE}.tmp"
mv "${CI_ZOWE_CONFIG_FILE}.tmp" "${CI_ZOWE_CONFIG_FILE}"
echo "[${SCRIPT_NAME}] current configuration is:"
cat "${CI_ZOWE_CONFIG_FILE}"
echo

# run temp fixes
if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
  cd $CI_INSTALL_DIR
  RUN_SCRIPT=temp-fixes-before-install.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT} ${CI_ZOWE_ROOT_DIR} ${FULL_EXTRACTED_ZOWE_FOLDER} ${CI_ZOSMF_URL}" 1800
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
      exit 1
    fi
  fi
fi

# start installation
echo "[${SCRIPT_NAME}] start installation ..."
cd $FULL_EXTRACTED_ZOWE_FOLDER/install
# FIXME: zowe-install.sh should exit by itself, not depends on timeout
RUN_SCRIPT=zowe-install.sh
run_script_with_timeout $RUN_SCRIPT 1800
EXIT_CODE=$?
if [[ "$EXIT_CODE" != "0" ]]; then
  echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
  echo "[${SCRIPT_NAME}][error] here is log file >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  cat $FULL_EXTRACTED_ZOWE_FOLDER/log/* || true
  echo "[${SCRIPT_NAME}][error] log end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  echo
  exit 1
else
  echo "[${SCRIPT_NAME}] ${RUN_SCRIPT} succeeds."
  echo "[${SCRIPT_NAME}] here is log file >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  cat $FULL_EXTRACTED_ZOWE_FOLDER/log/* || true
  echo "[${SCRIPT_NAME}] log end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  echo
fi
echo

# run temp fixes
if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
  cd $CI_INSTALL_DIR
  RUN_SCRIPT=temp-fixes-after-install.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT} ${CI_ZOWE_ROOT_DIR}" 1800
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
      exit 1
    fi
  fi
fi

# start installation
echo "[${SCRIPT_NAME}] start Zowe ..."
cd $CI_ZOWE_ROOT_DIR/scripts
RUN_SCRIPT=zowe-start.sh
(exec sh -c $RUN_SCRIPT)
EXIT_CODE=$?
if [[ "$EXIT_CODE" != "0" ]]; then
  echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
  exit 1
fi
echo

# move cli bundle out for next step
if [ "$HAS_EXTRA_ZOWE_FOLDER" = "1" ]; then
  echo "[${SCRIPT_NAME}] mv cli bundle out ..."
  mv $FULL_EXTRACTED_ZOWE_FOLDER/files/zowe-cli-bundle.zip $CI_INSTALL_DIR/extracted
fi

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
