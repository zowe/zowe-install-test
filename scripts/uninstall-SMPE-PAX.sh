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

if [ -d "${pathprefix}usr/lpp/zowe" ]; then
  if [ "${pathprefix}" = "/" ]; then
    # looks like an official location under /usr/lpp, only remove zowe
    echo "$SCRIPT deleting ${pathprefix}usr/lpp/zowe ..."
    (echo rm -fr "${pathprefix}usr/lpp/zowe" | su) || true
  else
    # testing folder, removing all
    echo "$SCRIPT deleting ${pathprefix}usr ..."
    (echo rm -fr "${pathprefix}usr" | su) || true
  fi
fi

# delete the datasets that install-SMPE-PAX.sh script creates
TSOCMD_RESULT=$(tsocmd delete '${hlq}.${FMID}.F1')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.${FMID}.F2')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.${FMID}.F3')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.${FMID}.F4')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.${FMID}.smpmcs')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.ZOWE.${FMID}.F1')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.ZOWE.${FMID}.F2')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.ZOWE.${FMID}.F3')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.ZOWE.${FMID}.F4')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.ZOWE.${FMID}.smpmcs')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.CSI')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPLOG')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPLOGA')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPLTS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPMTS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPPTS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPSCDS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SMPSTS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.AZWEAUTH')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.AZWESAMP')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.AZWEZFS')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SZWEAUTH')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.SMPE.SZWESAMP')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete '${hlq}.install.jcl')
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd delete TEST.jcl.*)
echo $TSOCMD_RESULT
TSOCMD_RESULT=$(tsocmd free all)
echo $TSOCMD_RESULT

echo script $SCRIPT ended from $SCRIPT_DIR
