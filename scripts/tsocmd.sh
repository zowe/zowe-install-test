#!/bin/sh

# Function: execute a list of TSO commands 

# Inputs  - a USS file of TSO commands to be executed
# Needs opercmd in its directory
# Outputs - Output is written to file tso.out in the current directory

# identify this script
SCRIPT_DIR="$(dirname $0)"
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

if [[ $# -ne 1 ]]
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
    $SCRIPT commands.txt
where commands.txt is a USS file of TSO commands to be executed.  

Output is written to file tso.out in the current directory
EndOfUsage
exit 
fi

tsoCommandsText=${1}
if [[ ! -r $tsoCommandsText ]]
then
    echo $SCRIPT ERROR: file $tsoCommandsText not readable
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

    echo; echo $SCRIPT function runJob started
    jclname=$1

    echo; echo $SCRIPT jclname=$jclname #jobname=$jobname

    # submit the job
    submit $jclname.jcl > /tmp/$$.submit.job.out
    if [[ $? -ne 0 ]]
    then
        echo; echo $SCRIPT submit JCL $jclname failed
        return 1
    fi

    # capture JOBID of submitted job
    jobid=`cat /tmp/$$.submit.job.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`

    echo; echo $SCRIPT JOBID=$jobid

    

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
        return 2
    else
        echo; echo $SCRIPT job JOB$jobid completed
    fi

    jobname=`sed -n 's/.*JOB(\([^ ]*\)).*/\1/p' /tmp/$$.dj.cc`
    echo $SCRIPT jobname $jobname
    
    # $DJ gives ...
    # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)

    $operdir/opercmd "\$DJ${jobid},CC" > /tmp/$$.dj.cc
    grep RC= /tmp/$$.dj.cc
    if [[ $? -ne 0 ]]
    then
        echo No return code for jobid $jobid
        return 3
    fi
    
    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/$$.dj.cc`
    echo; echo $SCRIPT return code for JOB$jobid is $rc

    if [[ $rc -gt 4 ]]
    then
        echo; echo $SCRIPT job "$jobname(JOB$jobid)" failed
        return 4
    fi
    echo; echo $SCRIPT function runJob ended
}

# prepare TSOCMD job JCL
userid=`logname`
if [[ ! -n "$userid" ]]
then  
  userid=$USER 
fi
if [[ ! -n "$userid" ]]
then  
  userid=TSTRADM 
fi

cat > runtso1.jcl <<EndOfJCL1
//RUNTSOCM JOB 1,REGION=0M,NOTIFY=&SYSUID,MSGCLASS=X
//*
//DELETE1 EXEC PGM=IEFBR14
//SYSUT1   DD  DSN=TSTRADM.TSO.OUT,DISP=(MOD,DELETE),SPACE=(TRK,0)
//*
//RUNTSO  EXEC PGM=IKJEFT01
//SYSTSPRT DD  DISP=(,CATLG),UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DSN=TSTRADM.TSO.OUT,DCB=(RECFM=FBM,LRECL=133)
//SYSOUT   DD  SYSOUT=*
//SYSTSIN  DD  *
EndOfJCL1

cat > runtso2.jcl <<EndOfJCL2
//COPYOUT EXEC PGM=IEBGENER
//SYSUT1   DD  DSN=TSTRADM.TSO.OUT,DISP=(SHR,KEEP)
//SYSUT2   DD PATH='tsouserpath/tso.out',
//            PATHOPTS=(OWRONLY,OCREAT,OTRUNC),
//            PATHMODE=SIRWXU,FILEDATA=TEXT
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  *
 GENERATE MAXFLDS=1
 RECORD FIELD=(133,1,,1)
//*
//DELETE2 EXEC PGM=IEFBR14
//SYSUT1   DD  DSN=TSTRADM.TSO.OUT,DISP=(MOD,DELETE),SPACE=(TRK,0)
EndOfJCL2

sed "s/TSTRADM/$userid/" runtso1.jcl > runtso1.e.jcl
sed "s/TSTRADM/$userid/;s+tsouserpath+`pwd`+" runtso2.jcl > runtso2.e.jcl

# build JCL deck
cat runtso1.e.jcl $tsoCommandsText runtso2.e.jcl > tsocmd.jcl
runJob tsocmd
if [[ $? -eq 0 ]]
then
    echo; echo $SCRIPT TSO commands output written to `pwd`/tso.out
fi

rm  runtso1.e.jcl runtso2.e.jcl

echo; echo script $SCRIPT ended from $SCRIPT_DIR