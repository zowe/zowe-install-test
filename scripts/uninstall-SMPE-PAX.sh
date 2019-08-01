#!/bin/sh

# Function: uninstall the Zowe SMP/E PAX file
# POC - no error checking

# Inputs  - none

# identify this script
SCRIPT_DIR="$(dirname $0)"
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

if [[ $# -ne 9 ]]
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT Hlq Csihlq Thlq Dhlq Pathprefix download_path zfs_path FMID PREFIX

   Parameter subsitutions:
 a.  for SMP/E jobs:
   Parm name	    Value used	    Meaning
   ---------        ----------      -------
 1  hlq	            ZOE     	    DSN HLQ
 2  csihlq	        ZOE.SMPE	    HLQ for our CSI
 3  thlq	        ZOE.SMPE	    TZONE HLQ
 4  dhlq	        ZOE.SMPE	    DZONE HLQ
 5  pathprefix	    /tmp/   	    Path Prefix of usr/lpp/zowe,
                                    where SMP/E will install zowe runtimes

 b.  For GIMUNZIP job:
 6  download_path   /tmp            where PAX and README are located
 7  zfs_path 	    /tmp/zowe/smpe	SMPDIR where GIMUNZIP unzips the PAX file
 8  FMID	        AZWE001	        The FMID for this release (omitted in archid of SMPMCS?)
 9  PREFIX	        ZOE.ZOWE        RELFILE prefix?

EndOfUsage
exit
fi

hlq=${1}
csihlq=$2
thlq=$3
dhlq=$4
pathprefix=$5
download_path=$6
zfs_path=$7
FMID=$8
PREFIX=$9

echo $SCRIPT    hlq=$1
echo $SCRIPT    csihlq=$2
echo $SCRIPT    thlq=$3
echo $SCRIPT    dhlq=$4
echo $SCRIPT    pathprefix=$5
echo $SCRIPT    download_path=$6
echo $SCRIPT    zfs_path=$7
echo $SCRIPT    FMID=$8
echo $SCRIPT    PREFIX=$9

# delete the datasets that install-SMPE-PAX.sh script creates
tso "delete ('${hlq}.${FMID}.F1')"
tso "delete ('${hlq}.${FMID}.F2')"
tso "delete ('${hlq}.${FMID}.F3')"
tso "delete ('${hlq}.${FMID}.F4')"
tso "delete ('${hlq}.${FMID}.smpmcs')"
tso "delete ('${hlq}.ZOWE.${FMID}.F1')"
tso "delete ('${hlq}.ZOWE.${FMID}.F2')"
tso "delete ('${hlq}.ZOWE.${FMID}.F3')"
tso "delete ('${hlq}.ZOWE.${FMID}.F4')"
tso "delete ('${hlq}.ZOWE.${FMID}.smpmcs')"
tso "delete ('${hlq}.SMPE.CSI')"
tso "delete ('${hlq}.SMPE.SMPLOG')"
tso "delete ('${hlq}.SMPE.SMPLOGA')"
tso "delete ('${hlq}.SMPE.SMPLTS')"
tso "delete ('${hlq}.SMPE.SMPMTS')"
tso "delete ('${hlq}.SMPE.SMPPTS')"
tso "delete ('${hlq}.SMPE.SMPSCDS')"
tso "delete ('${hlq}.SMPE.SMPSTS')"
tso "delete ('${hlq}.SMPE.AZWEAUTH')"
tso "delete ('${hlq}.SMPE.AZWESAMP')"
tso "delete ('${hlq}.SMPE.AZWEZFS')"
tso "delete ('${hlq}.SMPE.SZWEAUTH')"
tso "delete ('${hlq}.SMPE.SZWESAMP')"
tso "delete ('${hlq}.install.jcl')"
tso "delete (TEST.jcl.*)"
chmod -R 777 ${pathprefix}usr
rm -fR ${pathprefix}usr # because target is ${pathprefix}usr/lpp/zowe

echo script $SCRIPT ended from $SCRIPT_DIR
