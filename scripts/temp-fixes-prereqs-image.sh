#!/bin/bash -e

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
# This script will fix known issues of Zowe pre-reqs image
#
# This script should be placed into target image Ubuntu layer to start.
# 
# FIXME: eventually this script should be empty
################################################################################

SCRIPT_NAME=$(basename "$0")

################################################################################
# fix local resolver
# - ADCD.Z23A.TCPPARMS/GBLIPNOD
cd ~
rm GBLIPNOD.txt* || true
echo "[${SCRIPT_NAME}] fixing local resolver GBLIPNOD ..."
echo "[${SCRIPT_NAME}]   - downloading ADCD.Z23A.TCPPARMS/GBLIPNOD ..."
CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/GBLIPNOD --extract GBLIPNOD.txt)
if [[ "$CMD_RESULT" != *'AWSPDS042I'* ]]; then
  echo "[${SCRIPT_NAME}] failed to extract ADCD.Z23A.TCPPARMS/GBLIPNOD."
  exit 1
fi
echo "[${SCRIPT_NAME}]   - downloaded, replacing ..."
sed '2,2s/^.*$/127.0.0.1 LOCALHOST                                                                          /' GBLIPNOD.txt > GBLIPNOD.txt.1
cat GBLIPNOD.txt.1 | cut -c -80 > GBLIPNOD.txt
echo "[${SCRIPT_NAME}]   - replaced, putting it back ..."
CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/GBLIPNOD --overlay GBLIPNOD.txt)
if [[ "$CMD_RESULT" != *'AWSPDS055I'* ]]; then
  echo "[${SCRIPT_NAME}] failed to overwrite ADCD.Z23A.TCPPARMS/GBLIPNOD."
  exit 1
fi
echo "[${SCRIPT_NAME}]   - ADCD.Z23A.TCPPARMS/GBLIPNOD is updated."

################################################################################
# fix DNS entry and hostname
# - ADCD.Z23A.TCPPARMS(TCPDATA)
# - ADCD.Z23A.TCPPARMS(GBLTDATA)
# replace these lines
# > S0W1:   HOSTNAME   S0W1
# < RIVER:   HOSTNAME   RIVER
# > DOMAINORIGIN  DAL-EBIS.IHOST.COM
# < DOMAINORIGIN  ZOWE.COM
# > NSINTERADDR   9.20.136.11
# > NSINTERADDR   9.20.136.25
# < NSINTERADDR   8.8.8.8
# < NSINTERADDR   8.8.4.4
cd ~
rm GBLTDATA.txt* || true
rm TCPDATA.txt* || true
echo "[${SCRIPT_NAME}] fixing DNS entries and hostname ..."
# echo "[${SCRIPT_NAME}]   - downloading ADCD.Z23A.TCPPARMS/TCPDATA ..."
# CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/TCPDATA --extract TCPDATA.txt)
# if [[ "$CMD_RESULT" != *'AWSPDS042I'* ]]; then
#   echo "[${SCRIPT_NAME}] failed to extract ADCD.Z23A.TCPPARMS/TCPDATA."
#   exit 1
# fi
# echo "[${SCRIPT_NAME}]   - downloaded, replacing ..."
# sed 's/^[^;]\+:\s\+HOSTNAME\s\+.\+$/RIVER:   HOSTNAME   RIVER                                                                                    /' TCPDATA.txt > TCPDATA.txt.1
# sed 's/^DOMAINORIGIN\s\+.\+$/DOMAINORIGIN  ZOWE.ORG                                                                                   /' TCPDATA.txt.1 > TCPDATA.txt.2
# cat TCPDATA.txt.2 | cut -c -80 > TCPDATA.txt
# echo "[${SCRIPT_NAME}]   - replaced, putting it back ..."
# CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/TCPDATA --overlay TCPDATA.txt)
# if [[ "$CMD_RESULT" != *'AWSPDS055I'* ]]; then
#   echo "[${SCRIPT_NAME}] failed to overwrite ADCD.Z23A.TCPPARMS/TCPDATA."
#   exit 1
# fi
# echo "[${SCRIPT_NAME}]   - ADCD.Z23A.TCPPARMS/TCPDATA is updated."

echo "[${SCRIPT_NAME}]   - downloading ADCD.Z23A.TCPPARMS/GBLTDATA ..."
CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/GBLTDATA --extract GBLTDATA.txt)
if [[ "$CMD_RESULT" != *'AWSPDS042I'* ]]; then
  echo "[${SCRIPT_NAME}] failed to extract ADCD.Z23A.TCPPARMS/GBLTDATA."
  exit 1
fi
echo "[${SCRIPT_NAME}]   - downloaded, replacing ..."
# sed 's/^[^;]\+:\s\+HOSTNAME\s\+.\+$/RIVER:   HOSTNAME   RIVER                                                                                    /' GBLTDATA.txt > GBLTDATA.txt.1
# sed 's/^DOMAINORIGIN\s\+.\+$/DOMAINORIGIN  ZOWE.ORG                                                                                   /' GBLTDATA.txt.1 > GBLTDATA.txt.2
sed '0,/^NSINTERADDR\s\+9\./ s/^NSINTERADDR\s\+9\..\+$/NSINTERADDR   8.8.8.8                                                                                    /' GBLTDATA.txt > GBLTDATA.txt.3
sed '0,/^NSINTERADDR\s\+9\./ s/^NSINTERADDR\s\+9\..\+$/NSINTERADDR   8.8.4.4                                                                                    /' GBLTDATA.txt.3 > GBLTDATA.txt.4
cat GBLTDATA.txt.4 | cut -c -80 > GBLTDATA.txt
echo "[${SCRIPT_NAME}]   - replaced, putting it back ..."
CMD_RESULT=$(/usr/z1090/bin/pdsUtil /zaas1/zVolumes/A3SYS1 ADCD.Z23A.TCPPARMS/GBLTDATA --overlay GBLTDATA.txt)
if [[ "$CMD_RESULT" != *'AWSPDS055I'* ]]; then
  echo "[${SCRIPT_NAME}] failed to overwrite ADCD.Z23A.TCPPARMS/GBLTDATA."
  exit 1
fi
echo "[${SCRIPT_NAME}]   - ADCD.Z23A.TCPPARMS/GBLTDATA is updated."

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
