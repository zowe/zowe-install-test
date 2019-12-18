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
SCRIPT_PWD=$(cd $(dirname "$0") && pwd)
# this should list all known Zowe job names we ever shipped separated by space
# job name before 1.4.0: ZOWESVR
# job name after 1.4.0: ZOWESV1
# job name preparing for 1.5.0: ZOWE1SV
# job name preparing for 1.8.0: ZWE1SV
KNOWN_ZOWE_JOB_NAMES="ZOWESVR ZOWESV1 ZOWE1SV ZWE1SV"
# this should list all known xmem Zowe job names we ever shipped separated by space
# job name before 1.8.0: ZWESIS01
# job name preparing for 1.8.0: ZWESISTC
KNOWN_XMEM_JOB_NAMES="ZWESIS01 ZWEXMSTC ZWESISTC"
if [[ $KNOWN_XMEM_JOB_NAMES != *"${CIZT_ZSS_PROCLIB_MEMBER}"* ]]
then
  KNOWN_XMEM_JOB_NAMES="${KNOWN_XMEM_JOB_NAMES} ${CIZT_ZSS_PROCLIB_MEMBER}"
fi
# this should list all known FMIDs we ever shipped separated by space, so the
# uninstall script can uninstall any versions we ever installed.
KNOWN_SMPE_FMIDS=AZWE001
PROFILE=~/.profile
ZOWE_PROFILE=~/.zowe_profile

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
# Wrap call into $()
#
# NOTE: This function exists to solve the issue calling tsocmd/submit/cp directly
#       in pipeline will not exit properly.
################################################################################
function wrap_call {
  echo "[wrap_call] $@ >>>"
  CALL_RESULT=$($@)
  printf "%s\n[wrap_call] <<<\n" "$CALL_RESULT"
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
# load install config variables
if [ ! -f "${SCRIPT_PWD}/install-config.sh" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find install-config.sh"
  exit 1
fi
. "${SCRIPT_PWD}/install-config.sh"
if [ -z "${CIZT_ZOWE_ROOT_DIR}" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find \$CIZT_ZOWE_ROOT_DIR"
  exit 1
fi
if [ -f "opercmd" ]; then
  ensure_script_encoding opercmd "parse var command opercmd"
fi
if [ -f "uninstall-SMPE-PAX.sh" ]; then
  ensure_script_encoding uninstall-SMPE-PAX.sh
fi

################################################################################
echo "[${SCRIPT_NAME}] uninstall script started ..."
echo "[${SCRIPT_NAME}]   - Installation folder : $CIZT_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - Zowe Root folder    : $CIZT_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]   - Zowe User folder    : $CIZT_ZOWE_USER_DIR"
echo

if [ ! -f "${CIZT_INSTALL_DIR}/opercmd" ]; then
  echo "[${SCRIPT_NAME}][error] opercmd doesn't exist."
  exit 1;
fi

################################################################################
# stop ZWESISTC
echo "[${SCRIPT_NAME}] stopping ZWESISTC ..."
for XMEM_JOB_NAME in $KNOWN_XMEM_JOB_NAMES; do
  echo "[${SCRIPT_NAME}] - ${XMEM_JOB_NANE}"
  (exec "${CIZT_INSTALL_DIR}/opercmd" "P ${XMEM_JOB_NAME}")
done
echo

################################################################################
# stop Zowe
echo "[${SCRIPT_NAME}] stopping Zowe ..."
if [ -f "${CIZT_ZOWE_USER_DIR}/bin/zowe-stop.sh" ]; then
  (exec "${CIZT_ZOWE_USER_DIR}/bin/zowe-stop.sh")
fi
if [ -f "${CIZT_INSTALL_DIR}/opercmd" ]; then
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
wrap_call tsocmd 'RDELETE STARTED (ZWESIS*.*)'
wrap_call tsocmd 'RDELETE STARTED (ZWESVSTC.*)'
wrap_call tsocmd 'SETR RACLIST(STARTED) REFRESH'
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
# list all proclibs
PROCLIBS=$("${CIZT_INSTALL_DIR}/opercmd" '$d proclib' | grep 'DSNAME=.*\.PROCLIB' | sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/')

################################################################################
# removing old versions of Zowe proclib + current if they exists
KNOWN_ZOWE_PROCLIB_NAMES="ZOWESVR ZWESVSTC"
if [[ ${KNOWN_ZOWE_PROCLIB_NAMES} != *"${CIZT_PROCLIB_MEMBER}"* ]]
then
  KNOWN_ZOWE_PROCLIB_NAMES="${KNOWN_ZOWE_PROCLIB_NAMES} ${CIZT_PROCLIB_MEMBER}"
fi

echo "[${SCRIPT_NAME}] deleting Zowe PROC ..."
# listing all proclibs and members
FOUND_ZWESVSTC_AT=
for proclib in $PROCLIBS
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "'${proclib}'" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    for ZOWE_PROCLIB in $KNOWN_ZOWE_PROCLIB_NAMES; do
      if [ "${member}" = "${ZOWE_PROCLIB}" ]; then
        echo "[${SCRIPT_NAME}] found ${ZOWE_PROCLIB} in ${proclib}, deleting ..."
        wrap_call tsocmd DELETE "'${proclib}(${ZOWE_PROCLIB})'"
        FOUND_ZWESVSTC_AT=$proclib
      fi
    done
  done
done
# do we find ZWESVSTC?
if [ -z "$FOUND_ZWESVSTC_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find a Zowe proclib in PROCLIBs, skipped."
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
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CIZT_ZSS_LOADLIB_DS_NAME} ..."
members=$(tsocmd listds "'${CIZT_ZSS_LOADLIB_DS_NAME}'" members | sed -e '1,/--MEMBERS--/d')
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
  wrap_call tsocmd DELETE "'${FOUND_DS_MEMBER_AT}(${CIZT_ZSS_LOADLIB_MEMBER})'"
fi
echo

################################################################################
# removing xmem LOADLIB(ZWESAUX)
echo "[${SCRIPT_NAME}] deleting ${CIZT_ZSS_LOADLIB_DS_NAME}(${CIZT_ZSS_AUX_LOADLIB_MEMBER}) ..."
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CIZT_ZSS_LOADLIB_DS_NAME} ..."
members=$(tsocmd listds "'${CIZT_ZSS_LOADLIB_DS_NAME}'" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  if [ "${member}" = "${CIZT_ZSS_AUX_LOADLIB_MEMBER}" ]; then
    FOUND_DS_MEMBER_AT=$CIZT_ZSS_LOADLIB_DS_NAME
    break 2
  fi
done
# do we find CIZT_ZSS_AUX_LOADLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_ZSS_AUX_LOADLIB_MEMBER} in ${CIZT_ZSS_LOADLIB_DS_NAME}, skipped."
else
  echo "[${SCRIPT_NAME}] found ${CIZT_ZSS_AUX_LOADLIB_MEMBER} in ${FOUND_DS_MEMBER_AT}, deleting ..."
  wrap_call tsocmd DELETE "'${FOUND_DS_MEMBER_AT}(${CIZT_ZSS_AUX_LOADLIB_MEMBER})'"
fi
echo

################################################################################
# removing xmem PARMLIB(ZWESIP00)
KNOWN_XMEM_PARMLIB_NAMES="ZWESIP00 ZWEXMP00"
if [[ ${KNOWN_XMEM_PARMLIB_NAMES} != *"${CIZT_ZSS_PARMLIB_MEMBER}"* ]]
then
  KNOWN_XMEM_PARMLIB_NAMES="${KNOWN_XMEM_PARMLIB_NAMES} ${CIZT_ZSS_PARMLIB_MEMBER}"
fi
echo "[${SCRIPT_NAME}] deleting ${CIZT_ZSS_PARMLIB_DS_NAME}(${KNOWN_XMEM_PARMLIB_NAMES}) ..."
# listing all proclibs and members
FOUND_DS_MEMBER_AT=
echo "[${SCRIPT_NAME}] - finding in ${CIZT_ZSS_PARMLIB_DS_NAME} ..."
members=$(tsocmd listds "'${CIZT_ZSS_PARMLIB_DS_NAME}'" members | sed -e '1,/--MEMBERS--/d')
for member in $members
do
  echo "[${SCRIPT_NAME}]   - ${member}"
  for XMEM_PARMLIB in $KNOWN_XMEM_PARMLIB_NAMES; do
    if [ "${member}" = "${XMEM_PARMLIB}" ]; then
      echo "[${SCRIPT_NAME}] found ${XMEM_PARMLIB} in ${CIZT_ZSS_PARMLIB_DS_NAME}, deleting ..."
      wrap_call tsocmd DELETE "'${CIZT_ZSS_PARMLIB_DS_NAME}(${XMEM_PARMLIB})'"
      FOUND_DS_MEMBER_AT=$CIZT_ZSS_PARMLIB_DS_NAME
    fi
  done
done
# do we find CIZT_ZSS_PARMLIB_MEMBER?
if [ -z "$FOUND_DS_MEMBER_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find ${CIZT_ZSS_PARMLIB_MEMBER} in ${CIZT_ZSS_PARMLIB_DS_NAME}, skipped."
fi
echo

################################################################################
# removing old versions of xmem proclib + current if they exists
KNOWN_XMEM_PROCLIB_NAMES="ZWESIS01 ZWESISTC"
if [[ ${KNOWN_XMEM_PROCLIB_NAMES} != *"${CIZT_ZSS_PROCLIB_MEMBER}"* ]]
then
  KNOWN_XMEM_PROCLIB_NAMES="${KNOWN_XMEM_PROCLIB_NAMES} ${CIZT_ZSS_PROCLIB_MEMBER}"
fi

echo "[${SCRIPT_NAME}] deleting XMEM server PROC ..."
# listing all proclibs and members
FOUND_ZWESISTC_AT=
for proclib in $PROCLIBS
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "'${proclib}'" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    for XMEM_PROCLIB in $KNOWN_XMEM_PROCLIB_NAMES; do
      if [ "${member}" = "${XMEM_PROCLIB}" ]; then
        echo "[${SCRIPT_NAME}] found ${XMEM_PROCLIB} in ${proclib}, deleting ..."
        wrap_call tsocmd DELETE "'${proclib}(${XMEM_PROCLIB})'"
        FOUND_ZWESISTC_AT=$proclib
      fi
    done
  done
done
# do we find ZWESISTC?
if [ -z "$FOUND_ZWESISTC_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find XMEM in PROCLIBs, skipped."
fi
echo

################################################################################
# removing old versions of xmem aux proclib + current if they exists
KNOWN_AUX_PROCLIB_NAMES="ZWESAUX ZWESASTC"
if [[ ${KNOWN_AUX_PROCLIB_NAMES} != *"${CIZT_ZSS_AUX_PROCLIB_MEMBER}"* ]]
then
  KNOWN_AUX_PROCLIB_NAMES="${KNOWN_AUX_PROCLIB_NAMES} ${CIZT_ZSS_AUX_PROCLIB_MEMBER}"
fi

echo "[${SCRIPT_NAME}] deleting XMEM AUX PROC ..."
# listing all proclibs and members
FOUND_ZWESASTC_AT=
for proclib in $PROCLIBS
do
  echo "[${SCRIPT_NAME}] - finding in $proclib ..."
  members=$(tsocmd listds "'${proclib}'" members | sed -e '1,/--MEMBERS--/d')
  for member in $members
  do
    echo "[${SCRIPT_NAME}]   - ${member}"
    for AUX_PROCLIB in $KNOWN_AUX_PROCLIB_NAMES; do
      if [ "${member}" = "${AUX_PROCLIB}" ]; then
        echo "[${SCRIPT_NAME}] found ${AUX_PROCLIB} in ${proclib}, deleting ..."
        wrap_call tsocmd DELETE "'${proclib}(${AUX_PROCLIB})'"
        FOUND_ZWESASTC_AT=$proclib
      fi
    done
  done
done
# do we find ZWESASTC?
if [ -z "$FOUND_ZWESASTC_AT" ]; then
  echo "[${SCRIPT_NAME}][warn] cannot find XMEM AUX in PROCLIBs, skipped."
fi
echo

################################################################################
# removing datasetPrefix={userid}.ZWE
if [ -n "$USER" ]; then
  DATASET_PREFIX=$(echo "$USER.ZWE" | tr [a-z] [A-Z])
  echo "[${SCRIPT_NAME}] deleting ${DATASET_PREFIX}.* data sets ..."
  # listing 
  datasets=$(tsocmd listds "'$DATASET_PREFIX'" level | grep "$DATASET_PREFIX" | grep -v "UNABLE TO COMPLETE")
  for ds in $datasets
  do
    echo "[${SCRIPT_NAME}] - found ${ds}, deleting ..."
    wrap_call tsocmd DELETE "'${ds}'"
  done
  echo
fi

################################################################################
# removing folder
echo "[${SCRIPT_NAME}] removing installation folder $CIZT_ZOWE_ROOT_DIR ..."
(echo rm -fr $CIZT_ZOWE_ROOT_DIR | su) || true
echo "[${SCRIPT_NAME}] removing user folder $CIZT_ZOWE_USER_DIR ..."
(echo rm -fr $CIZT_ZOWE_USER_DIR | su) || true
echo "[${SCRIPT_NAME}] removing user folder $CIZT_ZOWE_KEYSTORE_DIR ..."
(echo rm -fr $CIZT_ZOWE_KEYSTORE_DIR | su) || true
echo

################################################################################
# uninstall SMP/e installation
echo "[${SCRIPT_NAME}] uninstalling SMP/e installation ..."
for FMID in $KNOWN_SMPE_FMIDS; do
  echo "[${SCRIPT_NAME}] - ${FMID}"
  ./uninstall-SMPE-PAX.sh \
    ${CIZT_SMPE_HLQ_DSN} \
    ${CIZT_SMPE_HLQ_CSI} \
    ${CIZT_SMPE_HLQ_TZONE} \
    ${CIZT_SMPE_HLQ_DZONE} \
    ${CIZT_SMPE_PATH_PREFIX} \
    ${CIZT_INSTALL_DIR} \
    ${CIZT_INSTALL_DIR}/extracted \
    ${FMID} \
    ${CIZT_SMPE_REL_FILE_PREFIX}
done
echo

################################################################################
echo "[${SCRIPT_NAME}] done."
exit 0
