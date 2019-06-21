#!/bin/sh

# install the Zowe SMP/E PAX file
# POC - no error checking
# Requires opercmd to check job RC

# identify this script
SCRIPT_DIR="$(dirname $0)"  
SCRIPT="$(basename $0)"  
echo script $SCRIPT started from $SCRIPT_DIR

zfs_path=/tmp               # change this to where PAX and README are located
FMID=AZWE001
README=readme.txt

# Inputs
# $zfs_path/$FMID.$README     # text
# $zfs_path/$FMID.pax.Z     # binary

# un-pax the main FMID file
# cd $zfs_path
cd /tmp/zowe/smpe           # my local work directory
pax -rvf $zfs_path/$FMID.pax.Z

# README -- README -- README

# convert the README to EBCDIC if required
iconv -f ISO8859-1 -t IBM-1047 $zfs_path/$FMID.$README > AZWE001.readme.ASCII.txt
chmod a+r AZWE001.readme.ASCII.txt

# extract the GIMUNZIP job
sed -n '/\/\/GIMUNZIP /,$p' AZWE001.readme.ASCII.txt > gimunzip.jcl0

# prepend the JOB statement
sed '1 i\
\/\/GIMUNZIP JOB' gimunzip.jcl0 > gimunzip.jcl1

# tailor the job
sed -f gimunzip.sed gimunzip.jcl1 > gimunzip.jcl

function runJob {
    echo
    echo function runJob started
    jclname=$1
    jobname=`echo $jclname | tr [a-z] [A-Z]`    # job names are upper case

    echo jclname=$jclname jobname=$jobname

    # submit job
    tsocmd oget " '$jclname.jcl'  'tstradm.TEST.jcl($jclname)' "
    jobid=`tsocmd submit "TEST.jcl($jclname)" | sed "s/JOB $jobname(JOB\([0-9]*\)) SUBMITTED/\1/"`
    echo JOBID=$jobid

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
        echo job not run in time
        exit 1
    else
        echo job "$jobname(JOB$jobid)" completed
    fi 

    # get job return code
    # GET /zosmf/restjobs/jobs/<jobname>/<jobid>?[step-data=Y|N]
    operdir=/u/stonecc/zowe/1.0.1/scripts/internal

    # RESPONSE=MV3B      $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0) 

    $operdir/opercmd "\$DJ${jobid},CC" > /tmp/$$.dj.cc
    grep RC= /tmp/$$.dj.cc
    if [[ $? -ne 0 ]]
    then
        echo No return code for jobid $jobid
        exit 3
    fi

    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/$$.dj.cc`
    echo return code for "$jobname(JOB$jobid)" is $rc

    if [[ $rc -gt 4 ]]
    then
        echo job "$jobname(JOB$jobid)" failed
        exit 2
    fi 
    echo function runJob ended
}

runJob gimunzip 


# SMP/E -- SMP/E -- SMP/E -- SMP/E



# jobs are to be run in this order
# .ZWE1SMPE. 
# .ZWE2RCVE. 
# .ZWE3ALOC. 
# .ZWE6DDEF. 
# .ZWE7APLY.

for smpejob in \
 ZWE1SMPE \
 ZWE2RCVE \
 ZWE3ALOC \
 ZWE6DDEF \
 ZWE7APLY
do 
    # tailor the SMP/E jobs (unedited ones are in .BAK)
    tsocmd oput "  'ZOE.AZWE001.F1.BAK($smpejob)' '$smpejob.jcl0' "

    sed -f smpejob.sed $smpejob.jcl0 > $smpejob.jcl

    if [[ $smpejob = ZWE7APLY ]]
    then
        echo fix error in APPLY job PAX parameter
        tsocmd oput "  'ZOE.SMPE.AZWE001.F4(ZWESHPAX)' 'ZWESHPAX.jcl0' "
        sed 's/ -pe / -pp /' ZWESHPAX.jcl0 > ZWESHPAX.jcl
        tsocmd oget " 'ZWESHPAX.jcl'  'ZOE.SMPE.AZWE001.F4(ZWESHPAX)' "
    fi 

    runJob $smpejob 

done

echo script $SCRIPT ended from $SCRIPT_DIR