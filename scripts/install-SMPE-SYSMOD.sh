#!/bin/sh
################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020, 2020
################################################################################
# Function: install the Zowe SMP/E SYSMOD
# POC - no error checking 
# Requires opercmd to check job RC

# Inputs
# -rw-r--r--   1 OMVSKERN SYS1     302706000 Feb 11 08:37 ZOWE.AZWE001.TMP0001
# -rw-r--r--   1 OMVSKERN SYS1          7457 Feb 11 08:37 ZOWE.AZWE001.TMP0001.readme.htm
# -rw-r--r--   1 OMVSKERN SYS1     182429840 Feb 11 08:37 ZOWE.AZWE001.TMP0002

# $download_path/ZOWE.$FMID.$SYSMOD1.readme.htm     # ASCII text of README htm file
# $download_path/ZOWE.$FMID.$SYSMOD1                # binary SMP/E SYSMOD file 1 of Zowe product
# $download_path/ZOWE.$FMID.$SYSMOD2                # binary SMP/E SYSMOD file 2 of Zowe product

# -rw-r--r--   1 OMVSKERN SYS1         877 Feb 12 09:23 Z1ALLOC.jcl
# -rw-r--r--   1 OMVSKERN SYS1         340 Feb 12 06:08 Z2ACCEPT.jcl
# -rw-r--r--   1 OMVSKERN SYS1         555 Feb 12 06:07 Z3RECEIV.jcl
# -rw-r--r--   1 OMVSKERN SYS1         241 Feb 12 06:08 Z4APPLY.jcl



# identify this script
# SCRIPT_DIR="$(dirname $0)"
SCRIPT_DIR=`pwd`
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

# allow to customize /tmp folder
if [ -z "${CIZT_TMP}" ]; then
  CIZT_TMP=/tmp
fi

#   The following stubs are to be replaced in the SMP/E PTF JCL:
#   - #hlq          ZOE             the high level qualifier used to upload the SYSMOD
#   - #volser       USER10          where to allocate SYSMOD datasets
#   - #globalcsi    ZOE.SMPE.CSI    the data set name of your CSI
#   - #dzone        DZONE           name of distribution zone
#   - #tzone        TZONE           name of target zone
#   - #fmid         AZWE001         name of FMID
#   - #sysmod1      TMP0001         SYSMOD file 1
#   - #sysmod2      TMP0002         SYSMOD file 2


if [[ $# -ne 9 ]]   
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT Hlq Csihlq download_path pathprefix FMID SYSMOD1 SYSMOD2 volser install

   Parameter subsitutions:
 
    Parm name       Value used      Meaning
    ---------       ----------      -------
 1  hlq             ZOE             DSN HLQ
 2  csihlq          ZOE.SMPE        HLQ for our CSI 
 3  pathprefix      /tmp/           Path Prefix of usr/lpp/zowe,
                                    where SMP/E will install zowe runtimes
 4  download_path   /tmp            where SYSMODs (binary) and JCL (EBCDIC) are located
 5  FMID            AZWE001         The FMID for base release 
 6  SYSMOD1         TMP0001         The name of the first  part of the SYSMOD
 7  SYSMOD2         TMP0002         The name of the second part of the SYSMOD 
 8  volser          USER10          volume serial number of a DASD volume to hold MVS datasets 
 9  install         install         run the install jobs       
                    uninstall       run the uninstall jobs

EndOfUsage
exit
fi

hlq=${1}
csihlq=$2
# thlq=$3
# dhlq=$4
pathprefix=$3
download_path=$4
FMID=$5
SYSMOD1=$6
SYSMOD2=$7
volser=$8
install=$9
# volser=B3IME1  # B3PRD3 # ZOWE02

echo $SCRIPT    hlq=$hlq
echo $SCRIPT    csihlq=$csihlq
# echo $SCRIPT    thlq=$thlq
# echo $SCRIPT    dhlq=$dhlq
echo $SCRIPT    pathprefix=$pathprefix
echo $SCRIPT    download_path=$download_path
# echo $SCRIPT    zfs_path=$zfs_path
echo $SCRIPT    FMID=$FMID
echo $SCRIPT    SYSMOD1=$SYSMOD1
echo $SCRIPT    SYSMOD2=$SYSMOD2
echo $SCRIPT    volser=$volser
echo $SCRIPT    install=$install

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

# Clean up sysmod data sets
wrap_call "tsocmd DELETE \"'${hlq}.ZOWE.${FMID}.$SYSMOD1'\"" 180
wrap_call "tsocmd DELETE \"'${hlq}.ZOWE.${FMID}.$SYSMOD2'\"" 180

echo "Before sysmod1 allocate:"
wrap_call "tsocmd listds \"'${hlq}.ZOWE.${FMID}.$SYSMOD1'\" history status members" 180
wrap_call "tsocmd listds \"'${hlq}.ZOWE.${FMID}.$SYSMOD2'\" history status members" 180

csidsn=$csihlq.CSI

for FMIDpath in \
    $download_path/ZOWE.$FMID.$SYSMOD1            \
    $download_path/ZOWE.$FMID.$SYSMOD2  
#  ignore   $download_path/ZOWE.$FMID.$SYSMOD1.readme.htm  for now
do
    if [[ ! -r $FMIDpath ]]
    then
        echo $SCRIPT ERROR: file $FMIDpath is missing or not readable
        exit 1
    fi
done

operdir=$SCRIPT_DIR         # this is where opercmd should be available

head -1 $operdir/opercmd | grep REXX 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: opercmd not found in $operdir or is not valid REXX 
    echo $SCRIPT INFO: CWD is `pwd`
    exit 9
fi

function runJob {

    echo; echo $SCRIPT function runJob started
    jclname=$1

    echo $SCRIPT jclname=$jclname #jobname=$jobname
    ls -l $jclname

    # show JCL for debugging purpose
    echo $SCRIPT ====================== content start ======================
    cat $jclname
    echo $SCRIPT ====================== content end ========================

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

    # echo; echo $SCRIPT JOBID=$jobid

    # wait for job to finish
    # APPLY can take 10 minutes on zD&T
    jobdone=0
    waitsecs=0
    for secs in 2 5 60 5 80 30 5 5 5 10 100 100 100 100 100
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
        waitsecs=$(($waitsecs+$secs))
        echo $SCRIPT INFO: Checking for completion of jobname $jobname jobid $jobid after $waitsecs seconds
        
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
        : # echo; echo $SCRIPT job JOB$jobid completed
    fi

    # jobname=`sed -n 's/.*JOB(\([^ ]*\)).*/\1/p' $CIZT_TMP/dj.$$.cc`
    # echo $SCRIPT jobname $jobname
    
    # $operdir/opercmd "\$DJ${jobid},CC" > $CIZT_TMP/dj.$$.cc
    grep RC= $CIZT_TMP/dj.$$.cc > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: no return code for jobid $jobid PID=$$
        echo $SCRIPT DISPLAY JOB output was:
        cat $CIZT_TMP/dj.$$.cc
        # do NOT ... return 3
    fi
    
    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' $CIZT_TMP/dj.$$.cc`
    # echo; echo $SCRIPT return code for JOB$jobid is $rc
    rm $CIZT_TMP/dj.$$.cc 2> /dev/null 
    if [[ $rc -gt 4 ]]
    then
        echo $SCRIPT ERROR: job "$jobname(JOB$jobid)" failed, RC=$rc 
        # do NOT ... return 4
    else
        echo $SCRIPT INFO: job "$jobname(JOB$jobid)" ended, RC=$rc
    fi
    echo; echo $SCRIPT function runJob ended
}

# SMP/E -- SMP/E -- SMP/E -- SMP/E
# jobs to be run
# comment out the jobs you don't want
smpejobs=
if [[ $install = install ]]
then
    smpejobs="$smpejobs Z0PTFUCL"
    smpejobs="$smpejobs Z1ALLOC"
    smpejobs="$smpejobs Z2ACCEPT"
    smpejobs="$smpejobs Z3RECEIV"
    smpejobs="$smpejobs Z4APPLY"
else
    smpejobs="$smpejobs Z6REST"
    smpejobs="$smpejobs Z7REJECT" 
    smpejobs="$smpejobs Z8DEALOC"
fi

# show tree before, excluding date/time
ls -l ${pathprefix}usr/lpp/zowe | awk '{print($1, $2, $3, $4, $5, $9)}' | tee $CIZT_TMP/usr.lpp.zowe.before.txt

# run these SMP/E jobs.  The FMID might already have been ACCEPTed, then Z2ACCEPT will fail RC=12
for smpejob in $smpejobs
do
    # $tsodir/tsocmd.sh oput "  '${PREFIX}.ZOWE.${FMID}.F1($smpejob)' '$smpejob.jcl0' "
    # cp "//'${PREFIX}.ZOWE.${FMID}.F1($smpejob)'" $zfs_path/$smpejob.jcl0

    # we can customize which volume to use for each job
    CUSTOMIZED_VAR="CIZT_SMPE_VOLSER_$smpejob"
    eval CUSTOMIZED_VOLSER=\$$CUSTOMIZED_VAR
    if [ -z "$CUSTOMIZED_VOLSER" ]; then
        CUSTOMIZED_VOLSER="$volser"
    fi

# JCL is in CWD, which is $CIZT_INSTALL_DIR
# echo CIZT_INSTALL_DIR contains ...
# ls -ld $CIZT_INSTALL_DIR
# ls -l  $CIZT_INSTALL_DIR
# ls -l  $smpejob.jcl
    # iconv -f IBM-850 -t IBM-1047 $smpejob.jcl > $CIZT_TMP/$smpejob.EBCDIC.jcl

#   The following stubs are to be replaced in the SMP/E PTF JCL:
#   - #hlq          ZOE             the high level qualifier used to upload the SYSMOD
#   - #volser       USER10          where to allocate SYSMOD datasets
#   - #globalcsi    ZOE.SMPE.CSI    the data set name of your CSI
#   - #dzone        DZONE           name of distribution zone
#   - #tzone        TZONE           name of target zone
#   - #fmid         AZWE001         name of FMID
#   - #sysmod1      TMP0001         SYSMOD file 1
#   - #sysmod2      TMP0002         SYSMOD file 2

    sed "\
        /^ *CHECK *$/d; \
        s/#tzone/TZONE/; \
        s/#dzone/DZONE/; \
        s/#hlq/${hlq}/; \
        s/#volser/${volser}/; \
        s/#globalcsi/${csidsn}/; \
        s/#fmid/${FMID}/; \
        s/#sysmod1/${SYSMOD1}/; \
        s/#sysmod2/${SYSMOD2}/" \
        $smpejob.jcl > $CIZT_TMP/$smpejob.sed.jcl

        # s/#csihlq/${csihlq}/; \
        # s/#csivol/$CUSTOMIZED_VOLSER/; \
        # s/#dvol/$CUSTOMIZED_VOLSER/; \
        # s/#tzone/TZONE/; \
        # s/#dzone/DZONE/; \
        # s/#hlq/${hlq}/; \
        # s/\[RFDSNPFX\]/ZOWE/; \
        # s/#thlq/${thlq}/; \
        # s/#dhlq/${dhlq}/; \
        # s/#tvol//; \
        # s/#dvol//; \
        # s/<job parameters>//; \
        # s+-PathPrefix-+${pathprefix}+; \
        # s+/\*VOLUMES(&CSIVOL)\*/+  VOLUMES(\&CSIVOL)  +; \
        # s+//\* *VOL=SER=&CSIVOL+// VOL=SER=\&CSIVOL+; \
        # s+//\* *VOL=SER=&DVOL+// VOL=SER=\&DVOL+; \
        # s+ADD DDDEF(SMPTLIB)+ADD DDDEF(SMPTLIB) CYL SPACE(864,25) DIR(10)+; \
        # s+//\*SMPTLIB+//SMPTLIB+; \
        # /^ *CHECK *$/d" \


# ... you may run out of space 
# E37 on SMPTLIB:
# ADD DDDEF(SMPTLIB)

    #   hlq was PREFIX in later PAXes, so that line was as below to cater for that
            # s/#hlq/${PREFIX}/; \
        # s/ RFPREFIX(.*)//" \
        # hlq was just $hlq before ... s/#hlq/${hlq}/; \

    runJob $CIZT_TMP/$smpejob.sed.jcl
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: SMP/E JOB $smpejob failed
        exit 2
    fi

    if [[ $smpejob = Z1ALLOC ]]
    then
        echo script $SCRIPT copying USS sysmod files to datasets
        echo "Before sysmod1 copies:"
        wrap_call tsocmd listds "'${hlq}.ZOWE.${FMID}.$SYSMOD1'" history status members
        wrap_call tsocmd listds "'${hlq}.ZOWE.${FMID}.$SYSMOD2'" history status members
        echo "uss sysmod 1: $(ls -al $download_path/ZOWE.$FMID.$SYSMOD1)"
        echo "uss sysmod 2: $(ls -al $download_path/ZOWE.$FMID.$SYSMOD2)"
        wrap_call cp $download_path/ZOWE.$FMID.$SYSMOD1 "//'${hlq}.ZOWE.${FMID}.$SYSMOD1'"
        wrap_call cp $download_path/ZOWE.$FMID.$SYSMOD2 "//'${hlq}.ZOWE.${FMID}.$SYSMOD2'"
        echo "After sysmod copy:"
        wrap_call tsocmd listds "'${hlq}.ZOWE.${FMID}.$SYSMOD1'" history status members
        wrap_call tsocmd listds "'${hlq}.ZOWE.${FMID}.$SYSMOD2'" history status members
        echo script $SCRIPT copy complete
    fi

done

# show tree after, excluding date/time
ls -l ${pathprefix}usr/lpp/zowe | awk '{print($1, $2, $3, $4, $5, $9)}' | tee $CIZT_TMP/usr.lpp.zowe.after.txt
diff $CIZT_TMP/usr.lpp.zowe.before.txt $CIZT_TMP/usr.lpp.zowe.after.txt

echo script $SCRIPT ended from $SCRIPT_DIR

