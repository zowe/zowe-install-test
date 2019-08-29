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
DEFAULT_CI_ZOWE_JOB_NAME=ZOWESV1
CI_ZOWE_ROOT_DIR=$DEFAULT_CI_ZOWE_ROOT_DIR
CI_INSTALL_DIR=$DEFAULT_CI_INSTALL_DIR
PROFILE=~/.profile
ZOWE_PROFILE=~/.zowe_profile
CI_ZOWE_DS_MEMBER=$DEFAULT_CI_ZOWE_DS_MEMBER
CI_ZOWE_JOB_NAME=$DEFAULT_CI_ZOWE_JOB_NAME
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
# Check script encoding and make sure it's IBM-1047
#
# NOTE: This function will also add execution permission to the script.
#
# Arguments:
#   $1        Scipt path
#   $2        Sample text to validate the conversion
#   $3        From encoding. Optional, default is ISO8859-1
#   $4        To encoding. Optional, default is IBM-1047
################################################################################
function ensure_script_encoding {
  SCRIPT_TO_CHECK=$1
  SAMPLE_TEXT=$2
  FROM_ENCODING=$3
  TO_ENCODING=$4

  if [ -z "$SAMPLE_TEXT" ]; then
    SAMPLE_TEXT="#!/"
  fi
  if [ -z "$FROM_ENCODING"]; then
    FROM_ENCODING=ISO8859-1
  fi
  if [ -z "$TO_ENCODING"]; then
    TO_ENCODING=IBM-1047
  fi

  iconv -f $FROM_ENCODING -t $TO_ENCODING "${SCRIPT_TO_CHECK}" > "${SCRIPT_TO_CHECK}.new"
  REQUIRE_THIS_CONVERT=$(cat "${SCRIPT_TO_CHECK}.new" | grep "${SAMPLE_TEXT}")
  if [ -n "$REQUIRE_THIS_CONVERT" ]; then
    mv "${SCRIPT_TO_CHECK}.new" "${SCRIPT_TO_CHECK}" && chmod +x "${SCRIPT_TO_CHECK}"
    echo "[${SCRIPT_NAME}] - ${SCRIPT_TO_CHECK} encoding is adjusted."
  else
    rm "${SCRIPT_TO_CHECK}.new"
    echo "[${SCRIPT_NAME}] - ${SCRIPT_TO_CHECK} encoding is NOT changed, failed to find pattern '${SAMPLE_TEXT}'."
  fi
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
  echo "  -j  Zowe job name. Optional, default is $DEFAULT_CI_ZOWE_JOB_NAME."
  echo
}
while getopts ":hi:t:m:j:" opt; do
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
    j)
      CI_ZOWE_JOB_NAME=$OPTARG
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
if [ -f "opercmd" ]; then
  ensure_script_encoding opercmd "parse var command opercmd"
fi
if [ -f "tsocmd.sh" ]; then
  ensure_script_encoding tsocmd.sh
fi
if [ -f "tsocmds.sh" ]; then
  ensure_script_encoding tsocmds.sh
fi
if [ -f "smpe-install-config.sh" ]; then
  ensure_script_encoding smpe-install-config.sh
fi
if [ -f "uninstall-SMPE-PAX.sh" ]; then
  ensure_script_encoding uninstall-SMPE-PAX.sh
fi

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
  # stop zowe before 1.4.0
  (exec "${CI_INSTALL_DIR}/opercmd" "C ${CI_ZOWE_DS_MEMBER}")
  # stop zowe after 1.4.0
  (exec "${CI_INSTALL_DIR}/opercmd" "C ${CI_ZOWE_JOB_NAME}")
else
  echo "[${SCRIPT_NAME}][WARN] - cannot find opercmd, please make sure ${CI_ZOWE_JOB_NAME} is stopped."
fi
echo

################################################################################
# delete started tasks
echo "[${SCRIPT_NAME}] deleting started tasks ..."
tsocmd.sh 'RDELETE STARTED (ZWESIS*.*)'
tsocmd.sh 'RDELETE STARTED (ZOWESVR.*)'
tsocmd.sh 'SETR RACLIST(STARTED) REFRESH'
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
# listing all proclibs and members
FOUND_ZOWESVR_AT=
procs=$("${CI_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd.sh listds "'${proclib}'" members | sed -e '1,/--MEMBERS--/d')
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
  tsocmd.sh DELETE "'${FOUND_ZOWESVR_AT}(${CI_ZOWE_DS_MEMBER})'"
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
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CI_XMEM_LOADLIB} ..."
members=$(tsocmd.sh listds "'${CI_XMEM_LOADLIB}'" members | sed -e '1,/--MEMBERS--/d')
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
  tsocmd.sh DELETE "'${FOUND_DS_MEMBER_AT}(${CI_XMEM_LOADLIB_MEMBER})'"
fi
echo

# removing xmem PARMLIB(ZWESIP00)
echo "[${SCRIPT_NAME}] deleting ${CI_XMEM_PARMLIB}(${CI_XMEM_PARMLIB_MEMBER}) ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CI_XMEM_PARMLIB} ..."
members=$(tsocmd.sh listds "'${CI_XMEM_PARMLIB}'" members | sed -e '1,/--MEMBERS--/d')
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
  tsocmd.sh DELETE "'${FOUND_DS_MEMBER_AT}(${CI_XMEM_PARMLIB_MEMBER})'"
fi
echo

# removing ZWESIS01
echo "[${SCRIPT_NAME}] deleting ${CI_XMEM_PROCLIB_MEMBER} PROC ..."
if [ ! -f "${CI_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi
# listing all proclibs and members
FOUND_ZWESIS01_AT=
procs=$("${CI_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')
for proclib in $procs
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd.sh listds "'${proclib}'" members | sed -e '1,/--MEMBERS--/d')
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
  tsocmd.sh DELETE "'${FOUND_ZWESIS01_AT}(${CI_XMEM_PROCLIB_MEMBER})'"
fi
echo

# removing folder
echo "[${SCRIPT_NAME}] removing installation folder ..."
rm -fr $CI_ZOWE_ROOT_DIR || true


################################################################################
# uninstall SMP/e installation
echo "[${SCRIPT_NAME}] uninstalling SMP/e installation ..."
. smpe-install-config.sh
for FMID in $SMPE_INSTALL_KNOWN_FMIDS; do
  echo "[${SCRIPT_NAME}] - ${FMID}"
  ./uninstall-SMPE-PAX.sh \
    ${SMPE_INSTALL_HLQ_DSN} \
    ${SMPE_INSTALL_HLQ_CSI} \
    ${SMPE_INSTALL_HLQ_TZONE} \
    ${SMPE_INSTALL_HLQ_DZONE} \
    ${SMPE_INSTALL_PATH_PREFIX} \
    ${CI_INSTALL_DIR} \
    ${CI_INSTALL_DIR}/extracted \
    ${FMID} \
    ${SMPE_INSTALL_REL_FILE_PREFIX}
done
echo

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
