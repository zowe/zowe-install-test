#!/bin/sh

# Function: execute a TSO command

# Inputs    - TSO command to be executed
# Pre-reqs  - Needs tsocmds.sh
# Outputs   - Output is written to STDOUT

echo $@ >  /tmp/$$.cmd.txt
tsocmds.sh /tmp/$$.cmd.txt
rm         /tmp/$$.cmd.txt 2> /dev/null 