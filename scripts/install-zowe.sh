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
DEFAULT_CI_ZOSMF_PORT=10443
DEFAULT_CI_ZOWE_ROOT_DIR=/zaas1/zowe
DEFAULT_CI_INSTALL_DIR=/zaas1/zowe-install
DEFAULT_CI_APIM_CATALOG_PORT=7552
DEFAULT_CI_APIM_DISCOVERY_PORT=7553
DEFAULT_CI_APIM_GATEWAY_PORT=7554
DEFAULT_CI_APIM_EXT_CERT=
DEFAULT_CI_APIM_EXT_CERT_ALIAS=
DEFAULT_CI_APIM_EXT_CERT_AUTH=
DEFAULT_CI_APIM_VERIFY_CERT=true
DEFAULT_CI_EXPLORER_HTTP_PORT=7080
DEFAULT_CI_EXPLORER_HTTPS_PORT=7443
DEFAULT_CI_ZLUX_HTTPS_PORT=8544
DEFAULT_CI_ZLUX_ZSS_PORT=8542
DEFAULT_CI_TERMINALS_SSH_PORT=22
DEFAULT_CI_TERMINALS_TELNET_PORT=23
DEFAULT_CI_PROCLIB_DS_NAME=auto
DEFAULT_CI_PROCLIB_MEMBER_NAME=ZOWESVR
CI_ZOWE_CONFIG_FILE=zowe-install.yaml
CI_ZOWE_PAX=
CI_SKIP_TEMP_FIXES=no
CI_UNINSTALL=no
CI_HOSTNAME=
CI_ZOSMF_PORT=$DEFAULT_CI_ZOSMF_PORT
CI_ZOWE_ROOT_DIR=$DEFAULT_CI_ZOWE_ROOT_DIR
CI_INSTALL_DIR=$DEFAULT_CI_INSTALL_DIR
CI_APIM_CATALOG_PORT=$DEFAULT_CI_APIM_CATALOG_PORT
CI_APIM_DISCOVERY_PORT=$DEFAULT_CI_APIM_DISCOVERY_PORT
CI_APIM_GATEWAY_PORT=$DEFAULT_CI_APIM_GATEWAY_PORT
CI_APIM_EXT_CERT=$DEFAULT_CI_APIM_EXT_CERT
CI_APIM_EXT_CERT_ALIAS=$DEFAULT_CI_APIM_EXT_CERT_ALIAS
CI_APIM_EXT_CERT_AUTH=$DEFAULT_CI_APIM_EXT_CERT_AUTH
CI_APIM_VERIFY_CERT=$DEFAULT_CI_APIM_VERIFY_CERT
CI_EXPLORER_HTTP_PORT=$DEFAULT_CI_EXPLORER_HTTP_PORT
CI_EXPLORER_HTTPS_PORT=$DEFAULT_CI_EXPLORER_HTTPS_PORT
CI_ZLUX_HTTPS_PORT=$DEFAULT_CI_ZLUX_HTTPS_PORT
CI_ZLUX_ZSS_PORT=$DEFAULT_CI_ZLUX_ZSS_PORT
CI_TERMINALS_SSH_PORT=$DEFAULT_CI_TERMINALS_SSH_PORT
CI_TERMINALS_TELNET_PORT=$DEFAULT_CI_TERMINALS_TELNET_PORT
CI_PROCLIB_DS_NAME=$DEFAULT_CI_PROCLIB_DS_NAME
CI_PROCLIB_MEMBER_NAME=$DEFAULT_CI_PROCLIB_MEMBER_NAME

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
  REQUIRE_THIS_CONVERT=$(cat "${SCRIPT_TO_CHECK}.new" | grep '#!/')
  if [ -n "$REQUIRE_THIS_CONVERT" ]; then
    mv "${SCRIPT_TO_CHECK}.new" "${SCRIPT_TO_CHECK}" && chmod +x "${SCRIPT_TO_CHECK}"
  else
    rm "${SCRIPT_TO_CHECK}.new"
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
  echo "  -h|--help             Display this help message."
  echo "  -s|--skip-fixes       If skip the temporary fixes before and after installation."
  echo "                        Optional, default is no."
  echo "  -u|--uninstall        If uninstall Zowe first."
  echo "                        Optional, default is no."
  echo "  -n|--hostname         The server public domain/IP."
  echo "  --zosmf-port          z/OSMF port for testing."
  echo "                        Optional, default is $DEFAULT_CI_ZOSMF_PORT."
  echo "  -t|--target-dir       Installation target folder."
  echo "                        Optional, default is $DEFAULT_CI_ZOWE_ROOT_DIR."
  echo "  -i|--install-dir      Installation working folder."
  echo "                        Optional, default is $DEFAULT_CI_INSTALL_DIR."
  echo "  --apim-catalog-port   catalogPort for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_CATALOG_PORT."
  echo "  --apim-discovery-port discoveryPort for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_DISCOVERY_PORT."
  echo "  --apim-gateway-port   gatewayPort for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_GATEWAY_PORT."
  echo "  --apim-cert           externalCertificate for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_EXT_CERT."
  echo "  --apim-cert-alias     externalCertificateAlias for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_EXT_CERT_ALIAS."
  echo "  --apim-ca             externalCertificateAuthorities for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_EXT_CERT_AUTH."
  echo "  --apim-verify-cert    verifyCertificatesOfServices for api-mediation."
  echo "                        Optional, default is $DEFAULT_CI_APIM_VERIFY_CERT."
  echo "  --explorer-http-port  httpPort for explorer-server."
  echo "                        Optional, default is $DEFAULT_CI_EXPLORER_HTTP_PORT."
  echo "  --explorer-https-port httpsPort for explorer-server."
  echo "                        Optional, default is $DEFAULT_CI_EXPLORER_HTTPS_PORT."
  echo "  --zlux-https-port     httpsPort for zlux-server."
  echo "                        Optional, default is $DEFAULT_CI_ZLUX_HTTPS_PORT."
  echo "  --zlux-zss-port       zssPort for zlux-server."
  echo "                        Optional, default is $DEFAULT_CI_ZLUX_ZSS_PORT."
  echo "  --term-ssh-port       sshPort for MVD terminals."
  echo "                        Optional, default is $DEFAULT_CI_TERMINALS_SSH_PORT."
  echo "  --term-telnet-port    telnetPort for MVD terminals."
  echo "                        Optional, default is $DEFAULT_CI_TERMINALS_TELNET_PORT."
  echo "  --proc-ds             dsName for PROCLIB."
  echo "                        Optional, default is $DEFAULT_CI_PROCLIB_DS_NAME."
  echo "  --proc-member         memberName for PROCLIB."
  echo "                        Optional, default is $DEFAULT_CI_PROCLIB_MEMBER_NAME."
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
    --zosmf-port)
      CI_ZOSMF_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--target-dir)
      CI_ZOWE_ROOT_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--install-dir)
      CI_INSTALL_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-catalog-port)
      CI_APIM_CATALOG_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-discovery-port)
      CI_APIM_DISCOVERY_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-gateway-port)
      CI_APIM_GATEWAY_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-cert)
      CI_APIM_EXT_CERT="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-cert-alias)
      CI_APIM_EXT_CERT_ALIAS="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-ca)
      CI_APIM_EXT_CERT_AUTH="$2"
      shift # past argument
      shift # past value
      ;;
    --apim-verify-cert)
      CI_APIM_VERIFY_CERT="$2"
      shift # past argument
      shift # past value
      ;;
    --explorer-http-port)
      CI_EXPLORER_HTTP_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --explorer-https-port)
      CI_EXPLORER_HTTPS_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --zlux-https-port)
      CI_ZLUX_HTTPS_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --zlux-zss-port)
      CI_ZLUX_ZSS_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --term-ssh-port)
      CI_TERMINALS_SSH_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --term-telnet-port)
      CI_TERMINALS_TELNET_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --proc-ds)
      CI_PROCLIB_DS_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    --proc-member)
      CI_PROCLIB_MEMBER_NAME="$2"
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
if [ -z "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] package is required."
  exit 1
fi
if [ ! -f "$CI_ZOWE_PAX" ]; then
  echo "[${SCRIPT_NAME}][error] cannot find the package file."
  exit 1
fi
if [ -z "$CI_HOSTNAME" ]; then
  echo "[${SCRIPT_NAME}][error] server hostname/IP is required."
  exit 1
fi
# convert encoding if those files uploaded
cd $CI_INSTALL_DIR
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

################################################################################
echo "[${SCRIPT_NAME}] installation script started ..."
echo "[${SCRIPT_NAME}]   - package file        : $CI_ZOWE_PAX"
echo "[${SCRIPT_NAME}]   - skip temp files     : $CI_SKIP_TEMP_FIXES"
echo "[${SCRIPT_NAME}]   - uninstall previous  : $CI_UNINSTALL"
echo "[${SCRIPT_NAME}]   - z/OSMF port         : $CI_ZOSMF_PORT"
echo "[${SCRIPT_NAME}]   - temporary folder    : $CI_INSTALL_DIR"
echo "[${SCRIPT_NAME}]   - install.            :"
echo "[${SCRIPT_NAME}]     - rootDir           : $CI_ZOWE_ROOT_DIR"
echo "[${SCRIPT_NAME}]   - zowe-server-proclib :"
echo "[${SCRIPT_NAME}]     - dsName            : $CI_PROCLIB_DS_NAME"
echo "[${SCRIPT_NAME}]     - memberName        : $CI_PROCLIB_MEMBER_NAME"
echo "[${SCRIPT_NAME}]   - api-mediation       :"
echo "[${SCRIPT_NAME}]     - catalogPort       : $CI_APIM_CATALOG_PORT"
echo "[${SCRIPT_NAME}]     - discoveryPort     : $CI_APIM_DISCOVERY_PORT"
echo "[${SCRIPT_NAME}]     - gatewayPort       : $CI_APIM_GATEWAY_PORT"
echo "[${SCRIPT_NAME}]     - externalCertificate            : $CI_APIM_EXT_CERT"
echo "[${SCRIPT_NAME}]     - externalCertificateAlias       : $CI_APIM_EXT_CERT_ALIAS"
echo "[${SCRIPT_NAME}]     - externalCertificateAuthorities : $CI_APIM_EXT_CERT_AUTH"
echo "[${SCRIPT_NAME}]     - verifyCertificatesOfServices   : $CI_APIM_VERIFY_CERT"
echo "[${SCRIPT_NAME}]   - explorer-server     :"
echo "[${SCRIPT_NAME}]     - httpPort          : $CI_EXPLORER_HTTP_PORT"
echo "[${SCRIPT_NAME}]     - httpsPort         : $CI_EXPLORER_HTTPS_PORT"
echo "[${SCRIPT_NAME}]   - zlux-server         :"
echo "[${SCRIPT_NAME}]     - httpsPort         : $CI_ZLUX_HTTPS_PORT"
echo "[${SCRIPT_NAME}]     - zssPort           : $CI_ZLUX_ZSS_PORT"
echo "[${SCRIPT_NAME}]   - terminals           :"
echo "[${SCRIPT_NAME}]     - sshPort           : $CI_TERMINALS_SSH_PORT"
echo "[${SCRIPT_NAME}]     - telnetPort        : $CI_TERMINALS_TELNET_PORT"
echo

if [[ "$CI_UNINSTALL" = "yes" ]]; then
  cd $CI_INSTALL_DIR
  RUN_SCRIPT=uninstall-zowe.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT} -t ${CI_ZOWE_ROOT_DIR} -m ${CI_PROCLIB_MEMBER_NAME}" 300
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
cat "${CI_ZOWE_CONFIG_FILE}" | \
  sed -e "/^install:/,\$s#rootDir=.*\$#rootDir=${CI_ZOWE_ROOT_DIR}#" | \
  sed -e "/^zowe-server-proclib:/,\$s#dsName=.*\$#dsName=${CI_PROCLIB_DS_NAME}#" | \
  sed -e "/^zowe-server-proclib:/,\$s#memberName=.*\$#memberName=${CI_PROCLIB_MEMBER_NAME}#" | \
  sed -e "/^api-mediation:/,\$s#catalogPort=.*\$#catalogPort=${CI_APIM_CATALOG_PORT}#" | \
  sed -e "/^api-mediation:/,\$s#discoveryPort=.*\$#discoveryPort=${CI_APIM_DISCOVERY_PORT}#" | \
  sed -e "/^api-mediation:/,\$s#gatewayPort=.*\$#gatewayPort=${CI_APIM_GATEWAY_PORT}#" | \
  sed -e "/^api-mediation:/,\$s#externalCertificate=.*\$#externalCertificate=${CI_APIM_EXT_CERT}#" | \
  sed -e "/^api-mediation:/,\$s#externalCertificateAlias=.*\$#externalCertificateAlias=${CI_APIM_EXT_CERT_ALIAS}#" | \
  sed -e "/^api-mediation:/,\$s#externalCertificateAuthorities=.*\$#externalCertificateAuthorities=${CI_APIM_EXT_CERT_AUTH}#" | \
  sed -e "/^api-mediation:/,\$s#verifyCertificatesOfServices=.*\$#verifyCertificatesOfServices=${CI_APIM_VERIFY_CERT}#" | \
  sed -e "/^explorer-server:/,\$s#httpPort=.*\$#httpPort=${CI_EXPLORER_HTTP_PORT}#" | \
  sed -e "/^explorer-server:/,\$s#httpsPort=.*\$#httpsPort=${CI_EXPLORER_HTTPS_PORT}#" | \
  sed -e "/^zlux-server:/,\$s#httpsPort=.*\$#httpsPort=${CI_ZLUX_HTTPS_PORT}#" | \
  sed -e "/^zlux-server:/,\$s#zssPort=.*\$#zssPort=${CI_ZLUX_ZSS_PORT}#" | \
  sed -e "/^terminals:/,\$s#sshPort=.*\$#sshPort=${CI_TERMINALS_SSH_PORT}#" | \
  sed -e "/^terminals:/,\$s#telnetPort=.*\$#telnetPort=${CI_TERMINALS_TELNET_PORT}#" > "${CI_ZOWE_CONFIG_FILE}.tmp"
mv "${CI_ZOWE_CONFIG_FILE}.tmp" "${CI_ZOWE_CONFIG_FILE}"
echo "[${SCRIPT_NAME}] current configuration is:"
cat "${CI_ZOWE_CONFIG_FILE}"
echo

# run temp fixes
if [ "$CI_SKIP_TEMP_FIXES" != "yes" ]; then
  cd $CI_INSTALL_DIR
  RUN_SCRIPT=temp-fixes-before-install.sh
  if [ -f "$RUN_SCRIPT" ]; then
    run_script_with_timeout "${RUN_SCRIPT} ${CI_ZOWE_ROOT_DIR} ${FULL_EXTRACTED_ZOWE_FOLDER}" 1800
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
    run_script_with_timeout "${RUN_SCRIPT} ${CI_ZOWE_ROOT_DIR} ${CI_HOSTNAME} ${CI_PROCLIB_MEMBER_NAME}" 1800
    EXIT_CODE=$?
    if [[ "$EXIT_CODE" != "0" ]]; then
      echo "[${SCRIPT_NAME}][error] ${RUN_SCRIPT} failed."
      exit 1
    fi
  fi
fi

# start zowe
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

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
