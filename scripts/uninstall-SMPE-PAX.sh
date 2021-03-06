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
 3  thlq	          ZOE.SMPE	    TZONE HLQ
 4  dhlq	          ZOE.SMPE	    DZONE HLQ
 5  pathprefix	    /tmp/   	    Path Prefix of usr/lpp/zowe,
                                    where SMP/E will install zowe runtimes

 b.  For GIMUNZIP job:
 6  download_path   /tmp            where PAX and README are located
 7  zfs_path 	      /tmp/zowe/smpe	SMPDIR where GIMUNZIP unzips the PAX file
 8  FMID	          AZWE001	        The FMID for this release (omitted in archid of SMPMCS?)
 9  PREFIX	        ZOE             RELFILE prefix?

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
wrap_call tsocmd delete "'$PREFIX.ZOWE.${FMID}.F1'"
wrap_call tsocmd delete "'$PREFIX.ZOWE.${FMID}.F2'"
wrap_call tsocmd delete "'$PREFIX.ZOWE.${FMID}.F3'"
wrap_call tsocmd delete "'$PREFIX.ZOWE.${FMID}.F4'"
wrap_call tsocmd delete "'$PREFIX.ZOWE.${FMID}.smpmcs'"
wrap_call tsocmd delete "'${csihlq}.CSI'"
wrap_call tsocmd delete "'${csihlq}.SMPLOG'"
wrap_call tsocmd delete "'${csihlq}.SMPLOGA'"
wrap_call tsocmd delete "'${csihlq}.SMPLTS'"
wrap_call tsocmd delete "'${csihlq}.SMPMTS'"
wrap_call tsocmd delete "'${csihlq}.SMPPTS'"
wrap_call tsocmd delete "'${csihlq}.SMPSCDS'"
wrap_call tsocmd delete "'${csihlq}.SMPSTS'"
wrap_call tsocmd delete "'${dhlq}.AZWEAUTH'"
wrap_call tsocmd delete "'${dhlq}.AZWESAMP'"
wrap_call tsocmd delete "'${dhlq}.AZWEZFS'"
wrap_call tsocmd delete "'${thlq}.SZWEAUTH'"
wrap_call tsocmd delete "'${thlq}.SZWESAMP'"
wrap_call tsocmd free all

echo script $SCRIPT ended from $SCRIPT_DIR
