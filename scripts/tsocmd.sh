#!/bin/sh

# Function: execute a TSO command

# Inputs    - TSO command to be executed
# Pre-reqs  - Needs tsocmds.sh
# Outputs   - Output is written to STDOUT

# allow to customize /tmp folder
if [ -z "${CIZT_TMP}" ]; then
  CIZT_TMP=/tmp
fi

echo $@ >  $CIZT_TMP/$$.cmd.txt
tsocmds.sh $CIZT_TMP/$$.cmd.txt
rm         $CIZT_TMP/$$.cmd.txt 2> /dev/null 
