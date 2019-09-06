#!/bin/sh

# Function: execute a list of TSO commands 

# Inputs    - a USS file of TSO commands to be executed
# Pre-reqs  - Needs opercmd in its directory
# Outputs   - Output is written to STDOUT

# identify this script
SCRIPT_DIR="$(dirname $0)"
SCRIPT="$(basename $0)"
# echo script $SCRIPT started from $SCRIPT_DIR

# allow to customize /tmp folder
if [ -z "${CIZT_TMP}" ]; then
  CIZT_TMP=/tmp
fi

if [[ $# -ne 1 ]]
then
echo $SCRIPT Usage: $SCRIPT commands.txt
cat <<EndOfUsage    
    where commands.txt is a USS file of TSO commands to be executed.  
    Output is written to STDOUT.
EndOfUsage
exit 
fi

tsoCommandsFile=${1}
if [[ ! -r $tsoCommandsFile ]]
then
    echo $SCRIPT ERROR: file $tsoCommandsFile not readable
    exit 1
fi 

operdir=$SCRIPT_DIR       # this is where opercmd should be available
ls $operdir/opercmd 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: opercmd not found in $operdir
    echo $SCRIPT INFO: CWD is `pwd`
    return 1
fi

function runJob {

    # echo; echo $SCRIPT function runJob started
    jclname=$1

    # echo; echo $SCRIPT jclname=$jclname #jobname=$jobname

    # submit the job using the USS submit command
    submit $jclname > $CIZT_TMP/submit.job.$$.out
    if [[ $? -ne 0 ]]
    then
        echo; echo $SCRIPT ERROR: submit JCL $jclname failed
        return 1
    fi

    # capture JOBID of submitted job
    jobid=`cat $CIZT_TMP/submit.job.$$.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`
    rm $CIZT_TMP/submit.job.$$.out 2> /dev/null 

    # echo; echo $SCRIPT JOBID=$jobid

    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100
    do
        sleep $secs
    
        $operdir/opercmd "\$DJ${jobid},CC" > $CIZT_TMP/dj.$$.cc
            # $DJ gives ...
            # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)
        grep CC= $CIZT_TMP/dj.$$.cc > /dev/null
        if [[ $? -eq 0 ]]
        then
            jobdone=1
            break
        fi
    done
    if [[ $jobdone -eq 0 ]]
    then
        echo $SCRIPT ERROR: job ${jobid} (PID=$$) not run in time
        echo $SCRIPT DISPLAY JOB output was:
        cat $CIZT_TMP/dj.$$.cc
        rm $CIZT_TMP/dj.$$.cc 2> /dev/null
        return 2
    else
        : # echo; echo $SCRIPT job JOB$jobid completed
    fi

    jobname=`sed -n 's/.*JOB(\([^ ]*\)).*/\1/p' $CIZT_TMP/dj.$$.cc`
    echo $SCRIPT jobname $jobname
    
    # $operdir/opercmd "\$DJ${jobid},CC" > $CIZT_TMP/dj.$$.cc
    grep RC= $CIZT_TMP/dj.$$.cc > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: no return code for jobid $jobid (PID=$$)
        echo $SCRIPT DISPLAY JOB output was:
        cat $CIZT_TMP/dj.$$.cc
        rm $CIZT_TMP/dj.$$.cc 2> /dev/null
        return 3
    fi
    
    # rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' $CIZT_TMP/dj.$$.cc`
    # # echo; echo $SCRIPT return code for JOB$jobid is $rc
    # rm $CIZT_TMP/dj.$$.cc 2> /dev/null 
    # if [[ $rc -gt 4 ]]
    # then
    #     echo $SCRIPT ERROR: job "$jobname(JOB$jobid)" failed, RC=$rc 
    #     return 4
    # fi
    # echo; echo $SCRIPT function runJob ended
}

cat > $CIZT_TMP/runtso1.$$.jcl <<EndOfJCL1
//RUNTSOCM JOB 1,REGION=0M
//*
//RUNTSO  EXEC PGM=IKJEFT01
//SYSTSPRT DD  DISP=(,PASS),UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DSN=&&CMDOUT,DCB=(RECFM=FBM,LRECL=133)
//SYSOUT   DD  SYSOUT=*
//SYSTSIN  DD  *
EndOfJCL1

cat > $CIZT_TMP/runtso2.$$.jcl <<EndOfJCL2
//*
//COPYOUT EXEC PGM=IEBGENER
//SYSUT1   DD  DSN=&&CMDOUT,DISP=(SHR,DELETE)
//SYSUT2   DD PATH='tsoCommandOut',
//            PATHOPTS=(OWRONLY,OCREAT,OTRUNC),
//            PATHMODE=SIRWXU,FILEDATA=TEXT
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  *
 GENERATE MAXFLDS=1
 RECORD FIELD=(133,1,,1)
//
EndOfJCL2

sed "s+tsoCommandOut+$CIZT_TMP/tso.cmd.$$.out+" $CIZT_TMP/runtso2.$$.jcl > $CIZT_TMP/runtso2.e.$$.jcl
rm $CIZT_TMP/runtso2.$$.jcl

# build JCL deck
cat $CIZT_TMP/runtso1.$$.jcl $tsoCommandsFile $CIZT_TMP/runtso2.e.$$.jcl > $CIZT_TMP/tsocmd.$$.jcl
rm  $CIZT_TMP/runtso1.$$.jcl $CIZT_TMP/runtso2.e.$$.jcl 2> /dev/null

runJob $CIZT_TMP/tsocmd.$$.jcl
# if [[ $? -eq 0 ]]
# then
#     echo; echo $SCRIPT TSO commands output written to `pwd`/tso.out
# fi

rm $CIZT_TMP/tsocmd.$$.jcl 2> /dev/null

if [[ ! -r $CIZT_TMP/tso.cmd.$$.out ]]
then
    # echo $SCRIPT ERROR: file $CIZT_TMP/tso.cmd.$$.out not readable
    exit 1
else
    cat $CIZT_TMP/tso.cmd.$$.out
fi 

rm $CIZT_TMP/tso.cmd.$$.out 2> /dev/null     # tidy up

# echo; echo script $SCRIPT ended from $SCRIPT_DIR
