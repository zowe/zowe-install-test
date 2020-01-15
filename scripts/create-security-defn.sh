#!/bin/sh

# Function: Run ZWESECUR job to create security definitions

# Inputs
# files/ZWESECUR.jcl
# $CIZT_INSTALL_DIR must be set

# identify this script
# SCRIPT_DIR="$(dirname $0)"
SCRIPT_DIR=`pwd`
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

# allow us to customize /tmp folder
if [ -z "${CIZT_TMP}" ]; then
  CIZT_TMP=/tmp
fi

operdir=$SCRIPT_DIR         # this is where opercmd should be available

head -1 $operdir/opercmd | grep REXX 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: opercmd not found in $operdir or is not valid REXX 
    echo $SCRIPT INFO: CWD is `pwd`
    exit 9
fi

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

function runJob {

    echo; echo $SCRIPT function runJob started
    jclname=$1

    # echo $SCRIPT jclname=$jclname
    # ls -l $jclname

    # # show JCL for debugging purpose
    # echo $SCRIPT ====================== content start ======================
    # cat $jclname
    # echo $SCRIPT ====================== content end ========================

    # submit the job using the USS submit command
    submit $jclname > $CIZT_TMP/submit.job.$$.out
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: submit JCL $jclname failed
        return 1
    else
        echo $SCRIPT INFO: JCL $jclname submitted
    fi

    # capture JOBID of submitted job
    jobid=`cat $CIZT_TMP/submit.job.$$.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`
    rm $CIZT_TMP/submit.job.$$.out 2> /dev/null 

    echo $SCRIPT JOBID=$jobid

    # wait for job to finish
    jobdone=0
    for secs in 1 1 1 5 5 5
    do
        sleep $secs
        $operdir/opercmd "\$DJ${jobid},CC" > $CIZT_TMP/dj.$$.cc
            # $DJ gives ...
            # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)  <-- accept this value
            # ... $HASP890 JOB(GIMUNZIP)  CC=()  <-- reject this value
        
        grep "$HASP890 JOB(.*) *CC=(.*)" $CIZT_TMP/dj.$$.cc > /dev/null
        if [[ $? -eq 0 ]]
        then
            jobname=`sed -n "s/.*$HASP890 JOB(\(.*\)) *CC=(.*).*/\1/p" $CIZT_TMP/dj.$$.cc`
            if [[ ! -n "$jobname" ]]
            then
                jobname=empty
            fi 
        else
            jobname=unknown
        fi
        echo $SCRIPT INFO: Checking for completion of jobname $jobname jobid $jobid
        
        grep "CC=(..*)" $CIZT_TMP/dj.$$.cc > /dev/null   # ensure CC() is not empty
        if [[ $? -eq 0 ]]
        then
            jobdone=1
            break
        fi
    done
    if [[ $jobdone -eq 0 ]]
    then
        echo $SCRIPT ERROR: job ${jobid} PID=$$ not run in time
        echo $SCRIPT DISPLAY JOB output was:
        cat $CIZT_TMP/dj.$$.cc
        rm $CIZT_TMP/dj.$$.cc 2> /dev/null 
        return 2
    else
        echo $SCRIPT job JOB$jobid completed
    fi

    grep RC= $CIZT_TMP/dj.$$.cc > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: no return code for jobid $jobid PID=$$
        echo $SCRIPT DISPLAY JOB output was:
        cat $CIZT_TMP/dj.$$.cc
        rm $CIZT_TMP/dj.$$.cc 2> /dev/null 
        return 3
    fi
    
    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' $CIZT_TMP/dj.$$.cc`
    echo $SCRIPT return code for JOB$jobid is $rc
    rm $CIZT_TMP/dj.$$.cc 2> /dev/null 
    if [[ $rc -gt 4 ]]
    then
        echo $SCRIPT ERROR: job "$jobname(JOB$jobid)" failed, RC=$rc 
        return 4
    fi
    echo $SCRIPT function runJob ended
    echo
}

# Tailor ZWESECUR.jcl for execution in our test environment
# Nullify ADDGROUP, ALTGROUP and ADDUSER
sed \
    -e "s+ADMINGRP=ZWEADMIN+ADMINGRP=${CIZT_ZSS_STC_GROUP}+" \
    -e "s+ZOWEUSER=ZWESVUSR+ZOWEUSER=$CIZT_ZSS_ZOWE_USER+" \
    -e "s+ZSSUSER=ZWESIUSR+ZSSUSER=$CIZT_ZSS_ZOWE_USER+" \
    -e "s+ZOWESTC=ZWESVSTC+ZOWESTC=${CIZT_PROCLIB_MEMBER}+" \
    -e "s+ZSSSTC=ZWESISTC+ZSSSTC=${CIZT_ZSS_PROCLIB_MEMBER}+" \
    -e "s+AUXSTC=ZWESASTC+AUXSTC=${CIZT_ZSS_AUX_PROCLIB_MEMBER}+" \
    -e "s+ADDGROUP+NOADDGROUP+" \
    -e "s+ALTGROUP+NOALTGROUP+" \
    -e "s+ADDUSER+NOADDUSER+" \
    $CIZT_INSTALL_DIR/../files/ZWESECUR.jcl > $CIZT_TMP/ZWESECUR.jcl

echo check edit ===
grep -e "^// *SET " \
    -e ADDGROUP \
    -e ALTGROUP \
    -e ADDUSER \
    $CIZT_TMP/ZWESECUR.jcl
echo check edit ===

# Run the ZWESECUR job
runJob $CIZT_TMP/ZWESECUR.jcl
rc=$?
if [[ $rc -ne 0 ]]
then
    echo $SCRIPT ERROR: ZWESECUR JOB failed
    exit $rc
fi

echo script $SCRIPT ended from $SCRIPT_DIR
