#!/bin/bash -e

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
# This script holds configurations for installation on the server
#
# MARIST College server
################################################################################

set +x

################################################################################
# constants
export CIZT_TARGET_SERVER=marist
export CIZT_TMP=/ZOWE/tmp
# directories
export CIZT_ZOWE_ROOT_DIR=/ZOWE/staging/zowe
export CIZT_ZOWE_USER_DIR=/ZOWE/tmp/.zowe
export CIZT_INSTALL_DIR=/ZOWE/zowe-installs
export CIZT_ZOWE_KEYSTORE_DIR=/ZOWE/tmp/keystore
# proclib / job name
export CIZT_PROCLIB_DS=auto
export CIZT_PROCLIB_MEMBER=ZWESVSTC
export CIZT_ZOWE_JOB_PREFIX=ZWE
# z/OSMF port
export CIZT_ZOSMF_PORT=10443
# Zowe ports
export CIZT_ZOWE_ZLUX_HTTPS_PORT=8544
export CIZT_ZOWE_ZLUX_ZSS_PORT=8542
export CIZT_ZOWE_EXPLORER_JOBS_PORT=8545
export CIZT_ZOWE_EXPLORER_DATASETS_PORT=8547
export CIZT_ZOWE_EXPLORER_UI_JES_PORT=8546
export CIZT_ZOWE_EXPLORER_UI_MVS_PORT=8548
export CIZT_ZOWE_EXPLORER_UI_USS_PORT=8550
export CIZT_ZOWE_API_MEDIATION_CATALOG_HTTP_PORT=7552
export CIZT_ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT=7553
export CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=7554
export CIZT_ZOWE_API_MEDIATION_EXT_CERT=
export CIZT_ZOWE_API_MEDIATION_EXT_CERT_ALIAS=
export CIZT_ZOWE_API_MEDIATION_EXT_CERT_AUTH=
export CIZT_ZOWE_API_MEDIATION_VERIFY_CERT=false
export CIZT_ZOWE_MVD_SSH_PORT=22
export CIZT_ZOWE_MVD_TELNET_PORT=623
# ZSS installation config
export CIZT_ZSS_PROCLIB_DS_NAME=VENDOR.PROCLIB
export CIZT_ZSS_PROCLIB_MEMBER=ZWESISTC
export CIZT_ZSS_AUX_PROCLIB_MEMBER=ZWESASTC
export CIZT_ZSS_PARMLIB_DS_NAME=ZOWEAD3.PARMLIB
export CIZT_ZSS_PARMLIB_MEMBER=ZWESIP00
export CIZT_ZSS_LOADLIB_DS_NAME=ZOWEAD3.LOADLIB
export CIZT_ZSS_LOADLIB_MEMBER=ZWESIS01
export CIZT_ZSS_AUX_LOADLIB_MEMBER=ZWESAUX
export CIZT_ZSS_ZOWE_USER=ZWESVUSR
export CIZT_ZSS_STC_USER_ID=2
export CIZT_ZSS_STC_GROUP=ZWEADMIN
export CIZT_ZSS_STC_USER=ZWESIUSR

# The SSH hostname/port stored as credential used to connect to test z/OS server
export CIZT_TEST_IMAGE_GUEST_SSH_HOSTPORT=ssh-marist-server-zzow01-hostport
# The SSH credential used to connect to test z/OS server
export CIZT_TEST_IMAGE_GUEST_SSH_CREDENTIAL=ssh-marist-server-zzow01
# zD&T host name should be converted
export CIZT_ZDNT_HOSTNAME=

# SMP/e installation parameters
export CIZT_SMPE_HLQ_DSN=ZOWEAD3
export CIZT_SMPE_HLQ_CSI=ZOWEAD3.SMPE
export CIZT_SMPE_HLQ_TZONE=ZOWEAD3.SMPE
export CIZT_SMPE_HLQ_DZONE=ZOWEAD3.SMPE
export CIZT_SMPE_REL_FILE_PREFIX=ZOWEAD3
export CIZT_SMPE_PATH_PREFIX=/ZOWE/staging/
export CIZT_SMPE_PATH_DEFAULT=usr/lpp/zowe
export CIZT_SMPE_VOLSER=ZOWE02
