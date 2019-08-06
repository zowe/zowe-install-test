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
# # delete the datasets that install-SMPE-PAX.sh script creates

chmod -R 777 ${pathprefix}usr
# tsocmd lu
rm -fR ${pathprefix}usr # because target is ${pathprefix}usr/lpp/zowe
# tso exec "'tstradm.smpe.jcl(rexcmd)'"
# kill -9 $$

cat > tso.cmd <<EndOfList
delete ('${hlq}.${FMID}.F1')
delete ('${hlq}.${FMID}.F2')
delete ('${hlq}.${FMID}.F3')
delete ('${hlq}.${FMID}.F4')
delete ('${hlq}.${FMID}.smpmcs')
delete ('${hlq}.ZOWE.${FMID}.F1')
delete ('${hlq}.ZOWE.${FMID}.F2')
delete ('${hlq}.ZOWE.${FMID}.F3')
delete ('${hlq}.ZOWE.${FMID}.F4')
delete ('${hlq}.ZOWE.${FMID}.smpmcs')
delete ('${hlq}.SMPE.CSI')
delete ('${hlq}.SMPE.SMPLOG')
delete ('${hlq}.SMPE.SMPLOGA')
delete ('${hlq}.SMPE.SMPLTS')
delete ('${hlq}.SMPE.SMPMTS')
delete ('${hlq}.SMPE.SMPPTS')
delete ('${hlq}.SMPE.SMPSCDS')
delete ('${hlq}.SMPE.SMPSTS')
delete ('${hlq}.SMPE.AZWEAUTH')
delete ('${hlq}.SMPE.AZWESAMP')
delete ('${hlq}.SMPE.AZWEZFS')
delete ('${hlq}.SMPE.SZWEAUTH')
delete ('${hlq}.SMPE.SZWESAMP')
delete ('${hlq}.install.jcl')
delete (TEST.jcl.*)
free all
EndOfList

cat runtso1.jcl tso.cmd runtso2.jcl > tsocmd.jcl
cat tsocmd.jcl # debug
submit tsocmd.jcl

    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100
    do
        sleep $secs
        grep ^END tso.out
        if [[ $? -eq 0 ]]
        then
            jobdone=1
            break
        fi
    done
    if [[ $jobdone -eq 0 ]]
    then
        echo; echo $SCRIPT job not run in time
        exit 2
    else
        echo; echo $SCRIPT job "$jobname(JOB$jobid)" completed
    fi

cat tso.out #debug

echo script $SCRIPT ended from $SCRIPT_DIR

