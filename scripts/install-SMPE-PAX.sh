#!/bin/sh

# Function: install the Zowe SMP/E PAX file
# POC - no error checking
# Requires opercmd to check job RC

# Inputs
# <OLD VERSION> $download_path/$FMID.$README      # EBCDIC text of README job JCL text file
# $download_path/$FMID.$README      # ASCII  text of README job JCL text file
# $download_path/$FMID.pax.Z        # binary SMP/E PAX file of Zowe product

# identify this script
# SCRIPT_DIR="$(dirname $0)"
SCRIPT_DIR=`pwd`
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

if [[ $# -ne 10 ]]   # until script is called with 10 parms
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT Hlq Csihlq Thlq Dhlq Pathprefix download_path zfs_path FMID PREFIX volser

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
10  volser          B3PRD3          volume serial number of a DASD volume to hold MVS datasets 

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
shift
volser=$9
# volser=B3IME1  # B3PRD3

echo $SCRIPT    hlq=$hlq
echo $SCRIPT    csihlq=$csihlq
echo $SCRIPT    thlq=$thlq
echo $SCRIPT    dhlq=$dhlq
echo $SCRIPT    pathprefix=$pathprefix
echo $SCRIPT    download_path=$download_path
echo $SCRIPT    zfs_path=$zfs_path
echo $SCRIPT    FMID=$FMID
echo $SCRIPT    PREFIX=$PREFIX
echo $SCRIPT    volser=$volser

operdir=$SCRIPT_DIR         # this is where opercmd should be available
tsodir=$SCRIPT_DIR          # this is where tsocmd(s).sh should be available

head -1 $operdir/opercmd | grep REXX 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: opercmd not found in $operdir or is not valid REXX 
    echo $SCRIPT INFO: CWD is `pwd`
    exit 9
fi

for cmd in tsocmds # tsocmd is not used
do
    head -1 $tsodir/$cmd.sh | grep '#!/bin/sh' 1> /dev/null 2> /dev/null
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: $cmd.sh not found in $tsodir or is not valid shell script  
        echo $SCRIPT INFO: CWD is `pwd`
        exit 9
    fi
done 


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
$tsodir/tsocmds.sh /tmp/tso.$$.cmd
rm /tmp/tso.$$.cmd 

chmod -R 777 ${pathprefix}usr
rm -fR ${pathprefix}usr # because target is ${pathprefix}usr/lpp/zowe

function runJob {

    echo; echo $SCRIPT function runJob started
    jclname=$1

    echo $SCRIPT jclname=$jclname #jobname=$jobname
    ls -l $jclname

    # submit the job using the USS submit command
    submit $jclname > /tmp/submit.job.$$.out
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: submit JCL $jclname failed
        return 1
    else
        echo $SCRIPT INFO: JCL $jclname submitted
    fi

    # capture JOBID of submitted job
    jobid=`cat /tmp/submit.job.$$.out \
        | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`
    rm /tmp/submit.job.$$.out 2> /dev/null 

    # echo; echo $SCRIPT JOBID=$jobid

    # wait for job to finish
    jobdone=0
    for secs in 1 5 10 30 100 300 500
    do
        sleep $secs
        $operdir/opercmd "\$DJ${jobid},CC" > /tmp/dj.$$.cc
            # $DJ gives ...
            # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)  <-- accept this value
            # ... $HASP890 JOB(GIMUNZIP)  CC=()  <-- reject this value
        
        grep "$HASP890 JOB(.*)  CC=(.*)" /tmp/dj.$$.cc > /dev/null
        if [[ $? -eq 0 ]]
        then
            jobname=`sed -n "s/.*$HASP890 JOB(\(.*\))  CC=(.*).*/\1/p" /tmp/dj.$$.cc`
            if [[ ! -n "$jobname" ]]
            then
                jobname=empty
            fi 
        else
            jobname=unknown
        fi
        echo $SCRIPT INFO: Checking for completion of jobname $jobname jobid $jobid
        
        grep "CC=(..*)" /tmp/dj.$$.cc > /dev/null   # ensure CC() is not empty
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
    
    rc=`sed -n 's/.*RC=\([0-9]*\))/\1/p' /tmp/dj.$$.cc`
    # echo; echo $SCRIPT return code for JOB$jobid is $rc
    rm /tmp/dj.$$.cc 2> /dev/null 
    if [[ $rc -gt 4 ]]
    then
        echo $SCRIPT ERROR: job "$jobname(JOB$jobid)" failed, RC=$rc 
        return 4
    fi
    # echo; echo $SCRIPT function runJob ended
}



# README -- README -- README

# README contains 3 jobs:
#
# //FILESYS     JOB - create and mount FILESYS
#
# //UNPAX       JOB - unpax the SMP/E PAX file
#
# //GIMUNZIP    JOB - runs GIMUNZIP to create SMP/E datasets and files

# convert the README to EBCDIC if required
iconv -f ISO8859-1 -t IBM-1047 $download_path/$FMID.$README > $zfs_path/readme.EBCDIC.jcl
grep "//GIMUNZIP " $zfs_path/readme.EBCDIC.jcl > /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: No GIMUNZIP JOB statement found in $download_path/$FMID.$README
    exit 1
fi

# Extract the GIMUNZIP job step
# sed -n '/\/\/GIMUNZIP /,$p' $download_path/$FMID.$README > gimunzip.jcl0
sed -n '/\/\/GIMUNZIP /,$p' $zfs_path/readme.EBCDIC.jcl > $zfs_path/gimunzip.jcl0
# chmod a+r AZWE001.readme.EBCDIC.txt

# Tailor the GIMUNZIP JCL
# sed "\
#     s+@zfs_path@+${zfs_path}+; \
#     s+&FMID\.+${FMID}+; \
#     s+@PREFIX@+${PREFIX}+" \
#     $zfs_path/gimunzip.jcl0 > $zfs_path/gimunzip.jcl1
sed "\
    s+@zfs_path@+${zfs_path}+; \
    s+&FMID\.+${FMID}+; \
    s+@PREFIX@+${PREFIX}+; \
    /<GIMUNZIP>/ a\\
    <TEMPDS volume=\"$volser\"> </TEMPDS> " \
    $zfs_path/gimunzip.jcl0 > $zfs_path/gimunzip.jcl1    

# Now also insert 'volume=' after 'archid'
# (drop this for now)
    # /archid=/ a\\
    # \ \ \ \ \ \ \ \ \ volume=\"$volser\"" \





# make the directory to hold the runtimes
mkdir -p ${pathprefix}usr/lpp/zowe/SMPE

# prepend the JOB statement
sed '1 i\
\/\/ZWE0GUNZ JOB' $zfs_path/gimunzip.jcl1 > $zfs_path/gimunzip.jcl

# un-pax the main FMID file
cd $zfs_path    # extract pax file and create work files here
echo; echo $SCRIPT un-PAX SMP/E file to $zfs_path
pax -rvf $download_path/$FMID.pax.Z

# Run the GIMUNZIP job
runJob $zfs_path/gimunzip.jcl
if [[ $? -ne 0 ]]
then
    echo $SCRIPT ERROR: GIMUNZIP JOB failed
    exit 1
fi


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
    # $tsodir/tsocmd.sh oput "  '${PREFIX}.ZOWE.${FMID}.F1($smpejob)' '$smpejob.jcl0' "
    cp "//'${PREFIX}.ZOWE.${FMID}.F1($smpejob)'" $zfs_path/$smpejob.jcl0
    
	# sed "s/#hlq/$PREFIX/" $smpejob.jcl0 > $smpejob.jcl1
    # sed -f smpejob.sed $smpejob.jcl1 > $smpejob.jcl

    # Also fix ... 
    # //*           VOL=SER=&CSIVOL, 
    # /*VOLUMES(DUMMY)*/

    sed "\
        s/#csihlq/${csihlq}/; \
        s/#csivol/$volser/; \
        s/#dvol/$volser/; \
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
        s+/\*VOLUMES(&CSIVOL)\*/+  VOLUMES(\&CSIVOL)  +; \
        s+//\* *VOL=SER=&CSIVOL+// VOL=SER=\&CSIVOL+; \
        s+//\* *VOL=SER=&DVOL+// VOL=SER=\&DVOL+; \
        s+ADD DDDEF(SMPTLIB)+ADD DDDEF(SMPTLIB) CYL SPACE(864,25) DIR(10)+; \
        s+//\*SMPTLIB+//SMPTLIB+; \
        /^ *CHECK *$/d" \
        $zfs_path/$smpejob.jcl0 > $zfs_path/$smpejob.jcl

# ... you may run out of space 
# E37 on SMPTLIB:
# ADD DDDEF(SMPTLIB)


    #   hlq was PREFIX in later PAXes, so that line was as below to cater for that
            # s/#hlq/${PREFIX}/; \
        # s/ RFPREFIX(.*)//" \
        # hlq was just $hlq before ... s/#hlq/${hlq}/; \

    # this test won't be required once the error is fixed
    if [[ $smpejob = ZWE7APLY ]]
    then
        echo; echo $SCRIPT fix error in APPLY job PAX parameter
        # $tsodir/tsocmd.sh oput "  '${csihlq}.${FMID}.F4(ZWESHPAX)' 'ZWESHPAX.jcl0' "
        cp "//'${csihlq}.${FMID}.F4(ZWESHPAX)'" $zfs_path/ZWESHPAX.jcl0
        echo; echo $SCRIPT find pe in JCL
        grep " -pe " $zfs_path/ZWESHPAX.jcl0
        sed 's/ -pe / -pp /' $zfs_path/ZWESHPAX.jcl0 > $zfs_path/ZWESHPAX.jcl
        # $tsodir/tsocmd.sh oget " 'ZWESHPAX.jcl'  '${csihlq}.${FMID}.F4(ZWESHPAX)' "
        cp $zfs_path/ZWESHPAX.jcl  "//'${csihlq}.${FMID}.F4(ZWESHPAX)'"
    fi

    runJob $zfs_path/$smpejob.jcl
    if [[ $? -ne 0 ]]
    then
        echo $SCRIPT ERROR: SMP/E JOB $smpejob failed
        exit 2
    fi

done

# TBD:  do this even if we quit early
rm /tmp/$$.submit.job.out
rm /tmp/$$.dj.cc

echo script $SCRIPT ended from $SCRIPT_DIR
