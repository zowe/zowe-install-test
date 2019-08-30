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
# This script defines how SMP/e build will be installed.
################################################################################

################################################################################
# constants
export SMPE_INSTALL_HLQ_DSN=ZOE
export SMPE_INSTALL_HLQ_CSI=ZOE.SMPE
export SMPE_INSTALL_HLQ_TZONE=ZOE.SMPE
export SMPE_INSTALL_HLQ_DZONE=ZOE.SMPE
export SMPE_INSTALL_REL_FILE_PREFIX=ZOE
export SMPE_INSTALL_PATH_PREFIX=/tmp/
export SMPE_INSTALL_PATH_DEFAULT=usr/lpp/zowe
# this should list all known FMIDs we ever shipped separated by space, so the
# uninstall script can uninstall any versions we ever installed.
export SMPE_INSTALL_KNOWN_FMIDS=AZWE001
