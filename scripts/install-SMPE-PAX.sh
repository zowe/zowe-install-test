#!/bin/sh

# Function: install the Zowe SMP/E PAX file
# POC - no error checking
# Requires opercmd to check job RC

# Inputs
# $download_path/$FMID.$README      # EBCDIC text of IEBUPDTE job JCL
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
README=README.jcl

# # prepare to run this script

# In case previous run failed,
# delete the datasets that this script creates
tsocmd "delete ('${hlq}.${FMID}.F1')"
tsocmd "delete ('${hlq}.${FMID}.F2')"
tsocmd "delete ('${hlq}.${FMID}.F3')"
tsocmd "delete ('${hlq}.${FMID}.F4')"
tsocmd "delete ('${hlq}.${FMID}.smpmcs')"
tsocmd "delete ('${hlq}.ZOWE.${FMID}.F1')"
tsocmd "delete ('${hlq}.ZOWE.${FMID}.F2')"
tsocmd "delete ('${hlq}.ZOWE.${FMID}.F3')"
tsocmd "delete ('${hlq}.ZOWE.${FMID}.F4')"
tsocmd "delete ('${hlq}.ZOWE.${FMID}.smpmcs')"
tsocmd "delete ('${hlq}.SMPE.CSI')"
tsocmd "delete ('${hlq}.SMPE.SMPLOG')"
tsocmd "delete ('${hlq}.SMPE.SMPLOGA')"
tsocmd "delete ('${hlq}.SMPE.SMPLTS')"
tsocmd "delete ('${hlq}.SMPE.SMPMTS')"
tsocmd "delete ('${hlq}.SMPE.SMPPTS')"
tsocmd "delete ('${hlq}.SMPE.SMPSCDS')"
tsocmd "delete ('${hlq}.SMPE.SMPSTS')"
tsocmd "delete ('${hlq}.SMPE.AZWEAUTH')"
tsocmd "delete ('${hlq}.SMPE.AZWESAMP')"
tsocmd "delete ('${hlq}.SMPE.AZWEZFS')"
tsocmd "delete ('${hlq}.SMPE.SZWEAUTH')"
tsocmd "delete ('${hlq}.SMPE.SZWESAMP')"
tsocmd "delete ('${hlq}.install.jcl')"
tsocmd "delete (TEST.jcl.*)"
rm -fR ${pathprefix}usr/lpp/zowe


function runJob {

    echo; echo $SCRIPT function runJob started
    jclname=$1
    jobname=`echo $jclname | tr [a-z] [A-Z]`    # job names are upper case

    echo; echo $SCRIPT jclname=$jclname jobname=$jobname


    # create a temporary dataset under my userid to hold the job JCL to be submitted
    tsocmd "delete (TEST.jcl.$jclname)" 1> /dev/null # delete the temporary dataset
    tsocmd "alloc dataset(TEST.jcl.$jclname) \
                new space(1) tracks \
                blksize(3120) \
                lrecl(80) \
                recfm(f,b) \
                dsorg(ps)"

    tsocmd oget " '$jclname.jcl'  TEST.jcl.$jclname "   # copy USS jcl file to MVS

    # submit the job
    tsocmd submit "TEST.jcl.$jclname" > /tmp/$$.submit.job.out
    if [[ $? -ne 0 ]]
    then
        echo; echo $SCRIPT submit job $jclname failed
        exit 1
    fi

    # capture JOBID of submitted job
    jobid=`cat /tmp/$$.submit.job.out \
        | sed "s/.*JOB $jobname(JOB\([0-9]*\)) SUBMITTED/\1/"`

    echo; echo $SCRIPT JOBID=$jobid



    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100
    do
        sleep $secs
        tsocmd status "$jobname(job$jobid)" | grep "JOB $jobname(JOB$jobid) ON OUTPUT QUEUE"
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

    # get job return code from JES
    # GET /zosmf/restjobs/jobs/<jobname>/<jobid>?[step-data=Y|N]
    operdir=$SCRIPT_DIR       # this is where opercmd should be available

    # RESPONSE=MV3B      $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)

    $operdir/opercmd "\$DJ${jobid},CC" > /tmp/$$.dj.cc
    grep RC= /tmp/$$.dj.cc
    if [[ $? -ne 0 ]]
    then
        echo No return code for jobid $jobid
        exit 3
    fi

    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/$$.dj.cc`
    echo; echo $SCRIPT return code for "$jobname(JOB$jobid)" is $rc

    if [[ $rc -gt 4 ]]
    then
        echo; echo $SCRIPT job "$jobname(JOB$jobid)" failed
        exit 4
    fi
    echo; echo $SCRIPT function runJob ended
}

# README -- README -- README

# convert the README to EBCDIC if required
# iconv -f ISO8859-1 -t IBM-1047 $download_path/$FMID.$README > iebupdte.jcl0  # old
# iconv -f ISO8859-1 -t IBM-1047 $download_path/$FMID.README.jcl > iebupdte.jcl0  # old
cp $download_path/$FMID.$README iebupdte.jcl0
# chmod a+r AZWE001.readme.EBCDIC.txt

# tailor the README
# tailor the job
# ... manually for now .... :sed -f gimunzip.sed iebupdte.jcl0 > iebupdte.jcl

# sed "\
#     s+@zfs_path@+${zfs_path}+; \
#     s+"&FMID..SMPMCS+"SMPMCS+; \
#     s+@PREFIX@.&FMID..SMPMCS+${hlq}.${FMID}.SMPMCS+; \
#     s+"&FMID..F1+"${FMID}.F1+; \
#     s+@PREFIX@.&FMID..F1+${hlq}.${FMID}.F1+; \
#     s+"&FMID..F2+"${FMID}.F2+; \
#     s+@PREFIX@.&FMID..F2+${hlq}.${FMID}.F2+; \
#     s+"&FMID..F3+"${FMID}.F3+; \
#     s+@PREFIX@.&FMID..F3+${hlq}.${FMID}.F3+; \
#     s+"&FMID..F4+"${FMID}.F4+; \
#     s+@PREFIX@.&FMID..F4+${hlq}.${FMID}.F4+; " \
#     iebupdte.jcl0 > iebupdte.jcl

sed "\
    s+@zfs_path@+${zfs_path}+; \
    s+&FMID\.+${FMID}+; \
    s+@PREFIX@+${PREFIX}+" \
    iebupdte.jcl0 > iebupdte.jcl

# Run the iebupdte job
    #  s+@PREFIX@+${hlq}+" \
runJob iebupdte

# loads 3 jobs:
#
# //FILESYS     JOB - create and mount FILESYS
#
# //UNPAX       JOB - unpax the SMP/E PAX file
#
# //GIMUNZIP    JOB - runs GIMUNZIP to create SMP/E datasets and files


# make the directory to hold the runtimes
mkdir -p ${pathprefix}usr/lpp/zowe/SMPE

# un-pax the main FMID file
# cd $zfs_path
cd /tmp/zowe/smpe           # my local work directory
echo; echo $SCRIPT un-PAX SMP/E file
pax -rvf $download_path/$FMID.pax.Z


# # extract the GIMUNZIP job
# sed -n '/\/\/GIMUNZIP /,$p' AZWE001.readme.EBCDIC.txt > gimunzip.jcl0

# # prepend the JOB statement
# sed '1 i\
# \/\/GIMUNZIP JOB' gimunzip.jcl0 > gimunzip.jcl1

# # tailor the job
# sed -f gimunzip.sed gimunzip.jcl1 > gimunzip.jcl

# fetch the GIMUNZIP job from the PDS that IEBUPDTE created
tsocmd oput "  '${hlq}.install.jcl(gimunzip)' 'gimunzip.jcl' "

# Run the GIMUNZIP job
runJob gimunzip


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
    tsocmd oput "  '${PREFIX}.ZOWE.${FMID}.F1($smpejob)' '$smpejob.jcl0' "
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
        tsocmd oput "  '${csihlq}.${FMID}.F4(ZWESHPAX)' 'ZWESHPAX.jcl0' "
        echo; echo $SCRIPT find pe in JCL
        grep " -pe " ZWESHPAX.jcl0
        sed 's/ -pe / -pp /' ZWESHPAX.jcl0 > ZWESHPAX.jcl
        tsocmd oget " 'ZWESHPAX.jcl'  '${csihlq}.${FMID}.F4(ZWESHPAX)' "
    fi

    runJob $smpejob

done

rm /tmp/$$.submit.job.out
rm /tmp/$$.dj.cc

echo script $SCRIPT ended from $SCRIPT_DIR
