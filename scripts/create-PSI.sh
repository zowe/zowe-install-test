SCRIPT_DIR=`pwd`
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

# allow to customize /tmp folder
if [ -z "${CIZT_TMP}" ]; then
  CIZT_TMP=/tmp
fi

if [[ $# -ne 9 ]]   # until script is called with 9 parms
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT 

   Parameter subsitutions:
 
   Parm name	  Value used	               Meaning
   ---------    ----------                 -------
 1  keyring	    izusvr/IZUKeyring.IZUDFLT  zOSMF keyring
 2  port	      10443                      Port where zOSMF is running
 3  swiname	    ZOWE_Software_Instance	   Name for Software Instance
 4  system	    S0W1                       zOSMF System Nickname
 5  csi	        ZOE.SMP.CSI   	           ZOWE CSI
 6  targetzone  TZONE                      Name of target zone
 7  export_path /tmp/export/	             Directory where will be Portable Software Instance
 8  psidsn	    ZOE.EXPORT                 Dataset name where will be stored JCL for PSI export
 9  volser	    B3PRD3                     Volume for psidsn
EndOfUsage
exit
fi

keyring=$1	    
port=$2	      
swiname=$3	    
system=$4	    
csi=$5   
targetzone=$6  
export_path=$7 
psidsn=$8	    
volser=$9


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

#TODO probably try to delete $psidsn even here
#TODO: add allocation and deletion of temporary dataset to ZWEPSI00
sed "\
        s/#port/$port/; \
        s/#safkeyring/$keyring/; \
        s/#softwareInstanceName/$swiname/; \
        s/#sysname/$system/; \
        s/#csi/$csi/; \
        s/#zones/$targetzone/; \
        s/#PSIdir/$export_path/; \
        s/#exportDSN/$psidsn/; \
        s/#volser/$volser/d" \
        ZWEPSI00 > ZWEPSI01
#TODO: somehow replace #host, #userid, #password

chmod 775 ZWEPSI01
./ZWEPSI01

if [[ $? -ne 0 ]]
then
  echo PSI ERROR: Export of Portable Software Instance Failed.
  exit 2
fi

#TODO: somehow upload/use scp the PSI
 
