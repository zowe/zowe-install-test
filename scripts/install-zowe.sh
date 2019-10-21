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
# This script will install Zowe
#
# This script should be placed into target image zOSaaS layer to start.
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
CI_ZOWE_CONFIG_FILE=zowe-install.yaml
CI_ZOWE_PAX=
CI_SKIP_TEMP_FIXES=no
CI_UNINSTALL=no
CI_HOSTNAME=

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
  echo "  -h|--help                       Display this help message."
  echo "  -s|--skip-fixes                 If skip the temporary fixes before and after installation."
  echo "                                  Optional, default is no."
  echo "  -u|--uninstall                  If uninstall Zowe first."
  echo "                                  Optional, default is no."
  echo "  -n|--hostname                   The server public domain/IP."
  echo
}

POSITIONALINDEX=0
POSITIONAL[$POSITIONALINDEX]=
while [ $# -gt 0 ]; do
  key="$1"

  case $key in
    -h|--help)
      usage
      exit 0
      ;;
    -s|--skip-fixes)
      CI_SKIP_TEMP_FIXES=yes
      shift # past argument
      ;;
    -u|--uninstall)
      CI_UNINSTALL=yes
      shift # past argument
      ;;
    -n|--hostname)
      CI_HOSTNAME="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      if [ ! "$1" = "${1#-}" ]; then
        echo "[${SCRIPT_NAME}][error] invalid option: $1" >&2
        exit 1
      fi 
      POSITIONAL[$POSITIONALINDEX]="$1" # save it in an array for later
      POSITIONALINDEX=$((POSITIONALINDEX + 1))
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
CI_ZOWE_PAX=$1

################################################################################
# essential validations
if [ ! -f install-config.sh ]; then
  echo "[${SCRIPT_NAME}][error] cannot find install-config.sh"
  exit 1
fi
ensure_script_encoding install-config.sh
. install-config.sh
if [ -z "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] package is required."
  exit 1
fi
if [ ! -f "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find the package file."
  exit 1
fi
CI_IS_SMPE=no
CI_SMPE_FMID=
echo "${CI_ZOWE_PAX}" | grep -qE "pax.Z$"
if [ $? -eq 0 ]; then
  CI_IS_SMPE=yes
  CI_SMPE_FMID=$(basename ${CI_ZOWE_PAX} | awk -F. '{print $1}')
  if [ -z "$CI_SMPE_FMID" ]; then
    echo "[${SCRIPT_NAME}][error] cannot determine SMP/e FMID."
    exit 1
  fi
  if [ ! -f "${CI_SMPE_FMID}.readme.txt" ]; then
    echo "[${SCRIPT_NAME}][error] cannot find the SMP/e readme file."
    exit 1
  fi
fi
export CI_IS_SMPE=$CI_IS_SMPE
if [ -z "$CI_HOSTNAME" ]; then
  echo "[${SCRIPT_NAME}][error] server hostname/IP is required."
  exit 1
fi
# convert encoding if those files uploaded
cd $CIZT_INSTALL_DIR
if [ -f "temp-fixes-after-install.sh" ]; then
  ensure_script_encoding temp-fixes-after-install.sh
fi
if [ -f "temp-fixes-after-started.sh" ]; then
  ensure_script_encoding temp-fixes-after-started.sh
fi
if [ -f "temp-fixes-before-install.sh" ]; then
  ensure_script_encoding temp-fixes-before-install.sh
fi
if [ -f "uninstall-zowe.sh" ]; then
  ensure_script_encoding uninstall-zowe.sh
fi
if [ -f "install-SMPE-PAX.sh" ]; then
  ensure_script_encoding install-SMPE-PAX.sh
fi
if [ -f "install-xmem-server.sh" ]; then
  ensure_script_encoding install-xmem-server.sh
fi
if [ -f "opercmd" ]; then
  ensure_script_encoding opercmd "parse var command opercmd"
fi

################################################################################
echo "[${SCRIPT_NAME}] installation script started ..."
echo "[${SCRIPT_NAME}]   - package file        : $CI_ZOWE_PAX"
echo "[${SCRIPT_NAME}]   - SMP/e package?      : $CI_IS_SMPE"
echo "[${SCRIPT_NAME}]   - SMP/e FMID          : $CI_SMPE_FMID"
echo "[${SCRIPT_NAME}]   - skip temp fixes     : $CI_SKIP_TEMP_FIXES"
echo "[${SCRIPT_NAME}]   - uninstall previous  : $CI_UNINSTALL"
echo "[${SCRIPT_NAME}]   - z/OSMF port         : $CIZT_ZOSMF_PORT"
echo "[${SCRIPT_NAME}]   - temporary folder    : $CIZT_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - install             :"
echo "[${SCRIPT_NAME}]     - rootDir           : $CIZT_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]     - userDir           : $CIZT_ZOWE_USER_DIR"
echo "[${SCRIPT_NAME}]     - prefix            : $CIZT_ZOWE_JOB_PREFIX"
echo "[${SCRIPT_NAME}]   - zowe-server-proclib :"
echo "[${SCRIPT_NAME}]     - dsName            : $CIZT_PROCLIB_DS"
echo "[${SCRIPT_NAME}]     - memberName        : $CIZT_PROCLIB_MEMBER"
echo "[${SCRIPT_NAME}]   - api-mediation       :"
echo "[${SCRIPT_NAME}]     - catalogPort       : $CIZT_ZOWE_API_MEDIATION_CATALOG_HTTP_PORT"
echo "[${SCRIPT_NAME}]     - discoveryPort     : $CIZT_ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT"
echo "[${SCRIPT_NAME}]     - gatewayPort       : $CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT"
echo "[${SCRIPT_NAME}]     - externalCertificate            : $CIZT_ZOWE_API_MEDIATION_EXT_CERT"
echo "[${SCRIPT_NAME}]     - externalCertificateAlias       : $CIZT_ZOWE_API_MEDIATION_EXT_CERT_ALIAS"
echo "[${SCRIPT_NAME}]     - externalCertificateAuthorities : $CIZT_ZOWE_API_MEDIATION_EXT_CERT_AUTH"
echo "[${SCRIPT_NAME}]     - verifyCertificatesOfServices   : $CIZT_ZOWE_API_MEDIATION_VERIFY_CERT"
echo "[${SCRIPT_NAME}]   - explorer-server     :"
echo "[${SCRIPT_NAME}]     - jobsPort          : $CIZT_ZOWE_EXPLORER_JOBS_PORT"
echo "[${SCRIPT_NAME}]     - dataSetsPort      : $CIZT_ZOWE_EXPLORER_DATASETS_PORT"
echo "[${SCRIPT_NAME}]   - explorer-ui         :"
echo "[${SCRIPT_NAME}]     - explorerJESUI     : $CIZT_ZOWE_EXPLORER_UI_JES_PORT"
echo "[${SCRIPT_NAME}]     - explorerMVSUI     : $CIZT_ZOWE_EXPLORER_UI_MVS_PORT"
echo "[${SCRIPT_NAME}]     - explorerUSSUI     : $CIZT_ZOWE_EXPLORER_UI_USS_PORT"
echo "[${SCRIPT_NAME}]   - zlux-server         :"
echo "[${SCRIPT_NAME}]     - httpsPort         : $CIZT_ZOWE_ZLUX_HTTPS_PORT"
echo "[${SCRIPT_NAME}]     - zssPort           : $CIZT_ZOWE_ZLUX_ZSS_PORT"
echo "[${SCRIPT_NAME}]   - terminals           :"
echo "[${SCRIPT_NAME}]     - sshPort           : $CIZT_ZOWE_MVD_SSH_PORT"
echo "[${SCRIPT_NAME}]     - telnetPort        : $CIZT_ZOWE_MVD_TELNET_PORT"
echo

if [[ "$CI_UNINSTALL" = "yes" ]]; then
  cd $CIZT_INSTALL_DIR
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

rm -fr ${CIZT_INSTALL_DIR}/extracted && mkdir -p ${CIZT_INSTALL_DIR}/extracted
if [[ "$CI_IS_SMPE" = "yes" ]]; then
  cd $CIZT_INSTALL_DIR
  # install SMP/e package
  echo "[${SCRIPT_NAME}] installing $CI_ZOWE_PAX to $CIZT_ZOWE_ROOT_DIR ..."
  RUN_SCRIPT="./install-SMPE-PAX.sh ${CIZT_SMPE_HLQ_DSN} ${CIZT_SMPE_HLQ_CSI} ${CIZT_SMPE_HLQ_TZONE} ${CIZT_SMPE_HLQ_DZONE} ${CIZT_SMPE_PATH_PREFIX} ${CIZT_INSTALL_DIR} ${CIZT_INSTALL_DIR}/extracted ${CI_SMPE_FMID} ${CIZT_SMPE_REL_FILE_PREFIX} ${CIZT_SMPE_VOLSER}"
  run_script_with_timeout "${RUN_SCRIPT}" 1800

  if [ ! -d "${CIZT_ZOWE_ROOT_DIR}/scripts" ]; then
    echo "[${SCRIPT_NAME}][error] installation is not successfully, ${CIZT_ZOWE_ROOT_DIR}/scripts doesn't exist."
    exit 1
  fi
  echo

  FULL_EXTRACTED_ZOWE_FOLDER=$CIZT_INSTALL_DIR/extracted

  # run temp fixes
  if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
    cd $CIZT_INSTALL_DIR
    RUN_SCRIPT=temp-fixes-before-install.sh
    if [ -f "$RUN_SCRIPT" ]; then
      run_script_with_timeout "${RUN_SCRIPT} ${FULL_EXTRACTED_ZOWE_FOLDER}" 1800
      EXIT_CODE=$?
      if [[ "$EXIT_CODE" != "0" ]]; then
        echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
        exit 1
      fi
    fi
  fi

  # configure installation
  echo "[${SCRIPT_NAME}] configure installation yaml ..."
  cd $CIZT_ZOWE_ROOT_DIR/scripts/configure
  cat "${CI_ZOWE_CONFIG_FILE}" | \
    sed -e "/^install:/,\$s#rootDir=.*\$#rootDir=${CIZT_ZOWE_ROOT_DIR}#" | \
    sed -e "/^install:/,\$s#userDir=.*\$#userDir=${CIZT_ZOWE_USER_DIR}#" | \
    sed -e "/^install:/,\$s#prefix=.*\$#prefix=${CIZT_ZOWE_JOB_PREFIX}#" | \
    sed -e "/^zowe-server-proclib:/,\$s#dsName=.*\$#dsName=${CIZT_PROCLIB_DS}#" | \
    sed -e "/^zowe-server-proclib:/,\$s#memberName=.*\$#memberName=${CIZT_PROCLIB_MEMBER}#" | \
    sed -e "/^api-mediation:/,\$s#catalogPort=.*\$#catalogPort=${CIZT_ZOWE_API_MEDIATION_CATALOG_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#discoveryPort=.*\$#discoveryPort=${CIZT_ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#gatewayPort=.*\$#gatewayPort=${CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificate=.*\$#externalCertificate=${CIZT_ZOWE_API_MEDIATION_EXT_CERT}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificateAlias=.*\$#externalCertificateAlias=${CIZT_ZOWE_API_MEDIATION_EXT_CERT_ALIAS}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificateAuthorities=.*\$#externalCertificateAuthorities=${CIZT_ZOWE_API_MEDIATION_EXT_CERT_AUTH}#" | \
    sed -e "/^api-mediation:/,\$s#verifyCertificatesOfServices=.*\$#verifyCertificatesOfServices=${CIZT_ZOWE_API_MEDIATION_VERIFY_CERT}#" | \
    sed -e "/^explorer-server:/,\$s#jobsPort=.*\$#jobsPort=${CIZT_ZOWE_EXPLORER_JOBS_PORT}#" | \
    sed -e "/^explorer-server:/,\$s#dataSetsPort=.*\$#dataSetsPort=${CIZT_ZOWE_EXPLORER_DATASETS_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerJESUI=.*\$#explorerJESUI=${CIZT_ZOWE_EXPLORER_UI_JES_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerMVSUI=.*\$#explorerMVSUI=${CIZT_ZOWE_EXPLORER_UI_MVS_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerUSSUI=.*\$#explorerUSSUI=${CIZT_ZOWE_EXPLORER_UI_USS_PORT}#" | \
    sed -e "/^zlux-server:/,\$s#httpsPort=.*\$#httpsPort=${CIZT_ZOWE_ZLUX_HTTPS_PORT}#" | \
    sed -e "/^zlux-server:/,\$s#zssPort=.*\$#zssPort=${CIZT_ZOWE_ZLUX_ZSS_PORT}#" | \
    sed -e "/^terminals:/,\$s#sshPort=.*\$#sshPort=${CIZT_ZOWE_MVD_SSH_PORT}#" | \
    sed -e "/^terminals:/,\$s#telnetPort=.*\$#telnetPort=${CIZT_ZOWE_MVD_TELNET_PORT}#" > "${CI_ZOWE_CONFIG_FILE}.tmp"
  mv "${CI_ZOWE_CONFIG_FILE}.tmp" "${CI_ZOWE_CONFIG_FILE}"
  echo "[${SCRIPT_NAME}] current Zowe configuration is:"
  cat "${CI_ZOWE_CONFIG_FILE}"

  # configure Zowe
  cd ${CIZT_ZOWE_ROOT_DIR}/scripts
  echo "[${SCRIPT_NAME}] installation is done, start configuring ..."
  ./configure/zowe-configure.sh < /dev/null
  if [ ! -f "zowe-start.sh" ]; then
    echo "[${SCRIPT_NAME}][error] installation is not successfully, cannot find zowe-start.sh."
    exit 1
  fi
  echo

  # update xmem installation config file
  echo "[${SCRIPT_NAME}] Zowe configuration is done, start installing xmem server ..."
  cd ${CIZT_SMPE_PATH_PREFIX}${CIZT_SMPE_PATH_DEFAULT}/xmem-server
  ${CIZT_INSTALL_DIR}/install-xmem-server.sh
  echo "[${SCRIPT_NAME}] all SMP/e install/config are done."
  echo
else
  # extract Zowe
  echo "[${SCRIPT_NAME}] extracting $CI_ZOWE_PAX to $CIZT_INSTALL_DIR/extracted ..."
  cd $CIZT_INSTALL_DIR/extracted
  pax -ppx -rf $CI_ZOWE_PAX
  EXIT_CODE=$?
  if [[ "$EXIT_CODE" == "0" ]]; then
    echo "[${SCRIPT_NAME}] $CI_ZOWE_PAX extracted."
  else
    echo "[${SCRIPT_NAME}][error] unpax Zowe failed."
    exit 1
  fi
  echo

  # check extracted folder
  # - old version will have several folders like files, install, licenses, scripts, etc
  # - new version will only have one folder of zowe-{version}
  FULL_EXTRACTED_ZOWE_FOLDER=$CIZT_INSTALL_DIR/extracted
  EXTRACTED_FILES=$(ls -1 $CIZT_INSTALL_DIR/extracted | wc -l | awk '{print $1}')
  HAS_EXTRA_ZOWE_FOLDER=0
  if [ "$EXTRACTED_FILES" = "1" ]; then
    HAS_EXTRA_ZOWE_FOLDER=1
    EXTRACTED_ZOWE_FOLDER=$(ls -1 $CIZT_INSTALL_DIR/extracted)
    FULL_EXTRACTED_ZOWE_FOLDER=$CIZT_INSTALL_DIR/extracted/$EXTRACTED_ZOWE_FOLDER
  fi

  # configure zowe installation
  echo "[${SCRIPT_NAME}] configure installation yaml ..."
  cd $FULL_EXTRACTED_ZOWE_FOLDER/install
  cat "${CI_ZOWE_CONFIG_FILE}" | \
    sed -e "/^install:/,\$s#rootDir=.*\$#rootDir=${CIZT_ZOWE_ROOT_DIR}#" | \
    sed -e "/^install:/,\$s#userDir=.*\$#userDir=${CIZT_ZOWE_USER_DIR}#" | \
    sed -e "/^install:/,\$s#prefix=.*\$#prefix=${CIZT_ZOWE_JOB_PREFIX}#" | \
    sed -e "/^zowe-server-proclib:/,\$s#dsName=.*\$#dsName=${CIZT_PROCLIB_DS}#" | \
    sed -e "/^zowe-server-proclib:/,\$s#memberName=.*\$#memberName=${CIZT_PROCLIB_MEMBER}#" | \
    sed -e "/^api-mediation:/,\$s#catalogPort=.*\$#catalogPort=${CIZT_ZOWE_API_MEDIATION_CATALOG_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#discoveryPort=.*\$#discoveryPort=${CIZT_ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#gatewayPort=.*\$#gatewayPort=${CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificate=.*\$#externalCertificate=${CIZT_ZOWE_API_MEDIATION_EXT_CERT}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificateAlias=.*\$#externalCertificateAlias=${CIZT_ZOWE_API_MEDIATION_EXT_CERT_ALIAS}#" | \
    sed -e "/^api-mediation:/,\$s#externalCertificateAuthorities=.*\$#externalCertificateAuthorities=${CIZT_ZOWE_API_MEDIATION_EXT_CERT_AUTH}#" | \
    sed -e "/^api-mediation:/,\$s#verifyCertificatesOfServices=.*\$#verifyCertificatesOfServices=${CIZT_ZOWE_API_MEDIATION_VERIFY_CERT}#" | \
    sed -e "/^explorer-server:/,\$s#jobsPort=.*\$#jobsPort=${CIZT_ZOWE_EXPLORER_JOBS_PORT}#" | \
    sed -e "/^explorer-server:/,\$s#dataSetsPort=.*\$#dataSetsPort=${CIZT_ZOWE_EXPLORER_DATASETS_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerJESUI=.*\$#explorerJESUI=${CIZT_ZOWE_EXPLORER_UI_JES_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerMVSUI=.*\$#explorerMVSUI=${CIZT_ZOWE_EXPLORER_UI_MVS_PORT}#" | \
    sed -e "/^explorer-ui:/,\$s#explorerUSSUI=.*\$#explorerUSSUI=${CIZT_ZOWE_EXPLORER_UI_USS_PORT}#" | \
    sed -e "/^zlux-server:/,\$s#httpsPort=.*\$#httpsPort=${CIZT_ZOWE_ZLUX_HTTPS_PORT}#" | \
    sed -e "/^zlux-server:/,\$s#zssPort=.*\$#zssPort=${CIZT_ZOWE_ZLUX_ZSS_PORT}#" | \
    sed -e "/^terminals:/,\$s#sshPort=.*\$#sshPort=${CIZT_ZOWE_MVD_SSH_PORT}#" | \
    sed -e "/^terminals:/,\$s#telnetPort=.*\$#telnetPort=${CIZT_ZOWE_MVD_TELNET_PORT}#" > "${CI_ZOWE_CONFIG_FILE}.tmp"
  mv "${CI_ZOWE_CONFIG_FILE}.tmp" "${CI_ZOWE_CONFIG_FILE}"
  echo "[${SCRIPT_NAME}] current Zowe configuration is:"
  cat "${CI_ZOWE_CONFIG_FILE}"
  echo

  # run temp fixes
  if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
    cd $CIZT_INSTALL_DIR
    RUN_SCRIPT=temp-fixes-before-install.sh
    if [ -f "$RUN_SCRIPT" ]; then
      run_script_with_timeout "${RUN_SCRIPT} ${FULL_EXTRACTED_ZOWE_FOLDER}" 1800
      EXIT_CODE=$?
      if [[ "$EXIT_CODE" != "0" ]]; then
        echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
        exit 1
      fi
    fi
  fi

  # run pre-install verify script
  echo "[${SCRIPT_NAME}] run pre-install verify script ..."
  cd $FULL_EXTRACTED_ZOWE_FOLDER/install
  RUN_SCRIPT=zowe-check-prereqs.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout $RUN_SCRIPT 1800
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][warning] ${RUN_SCRIPT} failed."
    fi
  fi
  echo

  # configure and install cross memory server
  cd $FULL_EXTRACTED_ZOWE_FOLDER/install
  ${CIZT_INSTALL_DIR}/install-xmem-server.sh
  echo

  # start Zowe installation
  echo "[${SCRIPT_NAME}] start Zowe installation ..."
  cd $FULL_EXTRACTED_ZOWE_FOLDER/install
  # FIXME: zowe-install.sh should exit by itself, not depends on timeout
  RUN_SCRIPT=zowe-install.sh
  run_script_with_timeout $RUN_SCRIPT 3600
  EXIT_CODE=$?
  if [[ "$EXIT_CODE" != "0" ]]; then
    echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
    echo "[${SCRIPT_NAME}][error] here is log file >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "[${SCRIPT_NAME}][error] - $FULL_EXTRACTED_ZOWE_FOLDER/log/*"
    cat $FULL_EXTRACTED_ZOWE_FOLDER/log/* || true
    echo "[${SCRIPT_NAME}][error] - $CIZT_ZOWE_ROOT_DIR/configure_log/*"
    cat $CIZT_ZOWE_ROOT_DIR/configure_log/* || true
    echo "[${SCRIPT_NAME}][error] - $CIZT_ZOWE_ROOT_DIR/scripts/configure/log/*"
    cat $CIZT_ZOWE_ROOT_DIR/scripts/configure/log/* || true
    echo "[${SCRIPT_NAME}][error] log end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    echo
    exit 1
  else
    echo "[${SCRIPT_NAME}] ${RUN_SCRIPT} succeeds."
    echo "[${SCRIPT_NAME}] here is log file >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "[${SCRIPT_NAME}] - $FULL_EXTRACTED_ZOWE_FOLDER/log/*"
    cat $FULL_EXTRACTED_ZOWE_FOLDER/log/* || true
    echo "[${SCRIPT_NAME}] - $CIZT_ZOWE_ROOT_DIR/configure_log/*"
    cat $CIZT_ZOWE_ROOT_DIR/configure_log/* || true
    echo "[${SCRIPT_NAME}] - $CIZT_ZOWE_ROOT_DIR/scripts/configure/log/*"
    cat $CIZT_ZOWE_ROOT_DIR/scripts/configure/log/* || true
    echo "[${SCRIPT_NAME}] log end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    echo
  fi
  echo
fi

# run temp fixes
if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
  cd $CIZT_INSTALL_DIR
  RUN_SCRIPT=temp-fixes-after-install.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT} ${CI_HOSTNAME}" 1800
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
      exit 1
    fi
  fi
fi

# start cross memory server
echo "[${SCRIPT_NAME}] start ZWESIS01 ..."
(exec "$CIZT_ZOWE_ROOT_DIR/scripts/internal/opercmd" "S ZWESIS01")
sleep 10
echo

# start zowe
echo "[${SCRIPT_NAME}] start Zowe ..."
cd $CIZT_ZOWE_ROOT_DIR/scripts
RUN_SCRIPT=zowe-start.sh
(exec sh -c $RUN_SCRIPT)
EXIT_CODE=$?
if [[ "$EXIT_CODE" != "0" ]]; then
  echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
  exit 1
fi
echo

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
