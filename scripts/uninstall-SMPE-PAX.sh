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

function runJob {

    echo; echo $SCRIPT function runJob started
    jclname=$1
    # jobname=`echo $jclname | tr [a-z] [A-Z]`    # job names are upper case

    echo; echo $SCRIPT jclname=$jclname #jobname=$jobname

    # submit the job
    submit $jclname.jcl > /tmp/$$.submit.job.out
    if [[ $? -ne 0 ]]
    then
        echo; echo $SCRIPT submit JCL $jclname failed
        exit 1
    fi

    # capture JOBID of submitted job
    jobid=`cat /tmp/$$.submit.job.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`

    echo; echo $SCRIPT JOBID=$jobid

    operdir=$SCRIPT_DIR       # this is where opercmd should be available

    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100
    do
        sleep $secs
    
        $operdir/opercmd "\$DJ${jobid},CC" > /tmp/$$.dj.cc
        grep CC= /tmp/$$.dj.cc
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
        echo; echo $SCRIPT job JOB$jobid completed
    fi

    jobname=`sed -n 's/.*JOB(\([^ ]*\)).*/\1/p' /tmp/$$.dj.cc`
    echo $SCRIPT jobname $jobname
    
    # get job return code from JES
    # GET /zosmf/restjobs/jobs/<jobname>/<jobid>?[step-data=Y|N]
    
    # RESPONSE=MV3B      $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)

    $operdir/opercmd "\$DJ${jobid},CC" > /tmp/$$.dj.cc
    grep RC= /tmp/$$.dj.cc
    if [[ $? -ne 0 ]]
    then
        echo No return code for jobid $jobid
        exit 3
    fi
    
    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/$$.dj.cc`
    echo; echo $SCRIPT return code for JOB$jobid is $rc

    if [[ $rc -gt 4 ]]
    then
        echo; echo $SCRIPT job "$jobname(JOB$jobid)" failed
        exit 4
    fi
    echo; echo $SCRIPT function runJob ended
}

chmod -R 777 ${pathprefix}usr
# tsocmd lu
rm -fR ${pathprefix}usr # because target is ${pathprefix}usr/lpp/zowe

pwd # where are we?
date # debug

# delete the datasets that install-SMPE-PAX.sh script creates
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

cat /u/tstradm/runtso1.jcl tso.cmd /u/tstradm/runtso2.jcl > tsocmd.jcl
runjob tsocmd

    # # wait for job to finish
    # jobdone=0
    # for secs in 1 5 10 30 100
    # do
    #     sleep $secs
    #     grep ^END /u/tstradm/tso.out > /dev/null
    #     if [[ $? -eq 0 ]]
    #     then
    #         jobdone=1
    #         break
    #     fi
    # done
    # if [[ $jobdone -eq 0 ]]
    # then
    #     echo; echo $SCRIPT job not run in time
    #     exit 2
    # else
    #     echo; echo $SCRIPT job "$jobname(JOB$jobid)" completed
    # fi

echo script $SCRIPT ended from $SCRIPT_DIR