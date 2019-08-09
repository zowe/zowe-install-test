#!/bin/sh

# Function: install the Zowe SMP/E PAX file
# POC - no error checking
# Requires opercmd to check job RC

# Inputs
# <OLD VERSION> $download_path/$FMID.$README      # EBCDIC text of README job JCL text file
# $download_path/$FMID.$README      # ASCII  text of README job JCL text file
# $download_path/$FMID.pax.Z        # binary SMP/E PAX file of Zowe product

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

# download_path=/tmp               # change this to where PAX and README are located
# FMID=AZWE001
README=readme.txt                   # the filename of the FMID.readme-v.m.r-smpe-test-nn-yyyymmddhhmmss.txt file

# # prepare to run this script

# In case previous run failed,
# delete the datasets that this script creates
cat > /tmp/tso.$$.cmd <<EndOfList
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

# execute the multiple TSO commands
tsocmds.sh /tmp/tso.$$.cmd
rm /tmp/tso.$$.cmd 

chmod -R 777 ${pathprefix}usr
rm -fR ${pathprefix}usr # because target is ${pathprefix}usr/lpp/zowe

operdir=$SCRIPT_DIR       # this is where opercmd should be available

echo operdir contains 
ls -l $operdir

head -1 $operdir/opercmd | grep REXX 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: opercmd not found in $operdir or is not valid REXX 
    echo $SCRIPT INFO: CWD is `pwd`
    exit 9
fi

function runJob {

    # echo; echo $SCRIPT function runJob started
    jclname=$1

    # echo; echo $SCRIPT jclname=$jclname #jobname=$jobname

    # submit the job using the USS submit command
    submit $jclname > /tmp/submit.job.$$.out
    if [[ $? -ne 0 ]]
    then
        echo; echo $SCRIPT ERROR: submit JCL $jclname failed
        return 1
    fi

    # capture JOBID of submitted job
    jobid=`cat /tmp/submit.job.$$.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`
    rm /tmp/submit.job.$$.out 2> /dev/null 

    # echo; echo $SCRIPT JOBID=$jobid

    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100
    do
        sleep $secs
    
        $operdir/opercmd "\$DJ${jobid},CC" > /tmp/dj.$$.cc
            # $DJ gives ...
            # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)
        grep CC= /tmp/dj.$$.cc > /dev/null
        if [[ $? -eq 0 ]]
        then
            jobdone=1
            break
        fi
    done
    if [[ $jobdone -eq 0 ]]
    then
        echo $SCRIPT ERROR: job ${jobid} not run in time
        return 2
    else
        : # echo; echo $SCRIPT job JOB$jobid completed
    fi

    jobname=`sed -n 's/.*JOB(\([^ ]*\)).*/\1/p' /tmp/dj.$$.cc`
    # echo $SCRIPT jobname $jobname
    
    $operdir/opercmd "\$DJ${jobid},CC" > /tmp/dj.$$.cc
    grep RC= /tmp/dj.$$.cc > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: no return code for jobid $jobid
        return 3
    fi
    
    # rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/dj.$$.cc`
    # # echo; echo $SCRIPT return code for JOB$jobid is $rc
    # rm /tmp/dj.$$.cc 2> /dev/null 
    # if [[ $rc -gt 4 ]]
    # then
    #     echo $SCRIPT ERROR: job "$jobname(JOB$jobid)" failed, RC=$rc 
    #     return 4
    # fi
    # echo; echo $SCRIPT function runJob ended
}



# README -- README -- README

# convert the README to EBCDIC if required
iconv -f ISO8859-1 -t IBM-1047 $download_path/$FMID.$README > gimunzip.EBCDIC.jcl
grep "//GIMUNZIP " gimunzip.EBCDIC.jcl > /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: No GIMUNZIP JOB statement found in $download_path/$FMID.$README
    exit 1
fi

# Extract the GIMUNZIP job step
# sed -n '/\/\/GIMUNZIP /,$p' $download_path/$FMID.$README > gimunzip.jcl0
sed -n '/\/\/GIMUNZIP /,$p' gimunzip.EBCDIC.jcl > gimunzip.jcl0
# chmod a+r AZWE001.readme.EBCDIC.txt

# tailor the README
# tailor the job

# Tailor the STEP JCL
sed "\
    s+@zfs_path@+${zfs_path}+; \
    s+&FMID\.+${FMID}+; \
    s+@PREFIX@+${PREFIX}+" \
    gimunzip.jcl0 > gimunzip.jcl1

# loads 3 jobs:
#
# //FILESYS     JOB - create and mount FILESYS
#
# //UNPAX       JOB - unpax the SMP/E PAX file
#
# //GIMUNZIP    JOB - runs GIMUNZIP to create SMP/E datasets and files


# make the directory to hold the runtimes
mkdir -p ${pathprefix}usr/lpp/zowe/SMPE

# prepend the JOB statement
sed '1 i\
\/\/GIMUNZIP JOB' gimunzip.jcl1 > gimunzip.jcl

# un-pax the main FMID file
cd $zfs_path    # extract pax file and create work files here
echo; echo $SCRIPT un-PAX SMP/E file in `pwd`
pax -rvf $download_path/$FMID.pax.Z

# Run the GIMUNZIP job
runJob $operdir/gimunzip.jcl

# SMP/E -- SMP/E -- SMP/E -- SMP/E

# run these SMP/E jobs
for smpejob in \
 ZWE1SMPE \
 ZWE2RCVE \
 ZWE3ALOC \
 ZWE6DDEF \
 ZWE7APLY \
 ZWE8ACPT
do
    # tailor the SMP/E jobs (unedited ones are in .BAK)
    # tsocmd oput "  '${hlq}.${FMID}.F1($smpejob)' '$smpejob.jcl0' "
    $operdir/tsocmd.sh oput "  '${PREFIX}.ZOWE.${FMID}.F1($smpejob)' '$smpejob.jcl0' "
    # ${hlq}.${FMID}.F1 ... ZOE.AZWE001.F1.BAK($smpejob)

	# sed "s/#hlq/$PREFIX/" $smpejob.jcl0 > $smpejob.jcl1
    # sed -f smpejob.sed $smpejob.jcl1 > $smpejob.jcl

    sed "\
        s/#csihlq/${csihlq}/; \
        s/#csivol/DUMMY/; \
        s/#tzone/TZONE/; \
        s/#dzone/DZONE/; \
        s/#hlq/${PREFIX}/; \
        s/\[RFDSNPFX\]/ZOWE/; \
        s/#thlq/${thlq}/; \
        s/#dhlq/${dhlq}/; \
        s/#tvol//; \
        s/#dvol//; \
        s/<job parameters>//; \
        s+-PathPrefix-+${pathprefix}+; \
        s/ CHECK //" \
        $smpejob.jcl0 > $smpejob.jcl

    #   hlq was PREFIX in later PAXes, so that line was as below to cater for that
            # s/#hlq/${PREFIX}/; \
        # s/ RFPREFIX(.*)//" \
        # hlq was just $hlq before ... s/#hlq/${hlq}/; \

    # this test won't be required once the error is fixed
    if [[ $smpejob = ZWE7APLY ]]
    then
        echo; echo $SCRIPT fix error in APPLY job PAX parameter
        tsocmd.sh oput "  '${csihlq}.${FMID}.F4(ZWESHPAX)' 'ZWESHPAX.jcl0' "
        echo; echo $SCRIPT find pe in JCL
        grep " -pe " ZWESHPAX.jcl0
        sed 's/ -pe / -pp /' ZWESHPAX.jcl0 > ZWESHPAX.jcl
        tsocmd.sh oget " 'ZWESHPAX.jcl'  '${csihlq}.${FMID}.F4(ZWESHPAX)' "
    fi

    runJob $smpejob.jcl

done

# TBD:  do this even if we quit early
rm /tmp/$$.submit.job.out
rm /tmp/$$.dj.cc

echo script $SCRIPT ended from $SCRIPT_DIR
