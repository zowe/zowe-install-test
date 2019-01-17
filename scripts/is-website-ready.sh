#!/bin/bash -e

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

################################################################################
# This script will check if a website is accessible
# 
# Example: ./is-website-ready.sh https://localhost:10443/zosmf/
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
DEFAULT_TEST_RETRIES=360
DEFAULT_TEST_INTERVAL=5
DEFAULT_CONNECTION_TIMEOUT=10
TEST_RETRIES=$DEFAULT_TEST_RETRIES
TEST_INTERVAL=$DEFAULT_TEST_INTERVAL
CONNECTION_TIMEOUT=$DEFAULT_CONNECTION_TIMEOUT
POST_DATA=

# allow to exit by ctrl+c
function finish {
  echo "[${SCRIPT_NAME}] interrupted"
  exit 1
}
trap finish SIGINT

################################################################################
# Check if a string is numeric
#
# Arguments:
#   $1        String to check
#
# Returns:
#   0         String is a number
#   1         String has non-numeric characters
################################################################################
function is_numeric {
  TO_CHECK=$1

  NON_NUMBER=$(echo "$TO_CHECK" | grep "[^0-9]" || true)
  [ -n "$NON_NUMBER" ] && return 1 || return 0
}

################################################################################
# parse parameters
function usage {
  echo "Check if a website is ready."
  echo
  echo "Usage: $SCRIPT_NAME [OPTIONS] url"
  echo
  echo "Options:"
  echo "  -h  Display this help message."
  echo "  -r  Test max retries. Optional, default is $DEFAULT_TEST_RETRIES."
  echo "  -t  Test interval. Optional, default is $DEFAULT_TEST_INTERVAL."
  echo "  -c  Connection timeout. Optional, default is $DEFAULT_CONNECTION_TIMEOUT."
  echo "  -d  Send HTTP POST with data instead of GET. Optional."
  echo
}
while getopts ":hr:t:c:d:" opt; do
  case $opt in
    h)
      usage
      exit 0
      ;;
    r)
      is_numeric $OPTARG
      IS_NUMERIC_RESULT=$?
      if [ "$IS_NUMERIC_RESULT" = "0" ]; then
        TEST_RETRIES=$OPTARG
      else
        echo "[${SCRIPT_NAME}][error] invalid option argument: -${opt} can only take a number value." 1>&2
        exit 1
      fi
      ;;
    t)
      is_numeric $OPTARG
      IS_NUMERIC_RESULT=$?
      if [ "$IS_NUMERIC_RESULT" = "0" ]; then
        TEST_INTERVAL=$OPTARG
      else
        echo "[${SCRIPT_NAME}][error] invalid option argument: -${opt} can only take a number value." 1>&2
        exit 1
      fi
      ;;
    c)
      is_numeric $OPTARG
      IS_NUMERIC_RESULT=$?
      if [ "$IS_NUMERIC_RESULT" = "0" ]; then
        CONNECTION_TIMEOUT=$OPTARG
      else
        echo "[${SCRIPT_NAME}][error] invalid option argument: -${opt} can only take a number value." 1>&2
        exit 1
      fi
      ;;
    d)
      POST_DATA=$OPTARG
      ;;
    \?)
      echo "[${SCRIPT_NAME}][error] invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "[${SCRIPT_NAME}][error] invalid option argument: -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))
TEST_URL=$1

################################################################################
# essential validations
if [ -z "$TEST_URL" ]; then
  echo "[${SCRIPT_NAME}][error] url is required."
  exit 1
fi
if [[ "$TEST_URL" != "http"* ]]; then
  echo "[${SCRIPT_NAME}][error] url ($TEST_URL) is invalid."
  exit 1
fi

################################################################################
echo "[${SCRIPT_NAME}] testing $TEST_URL ..."
echo "[${SCRIPT_NAME}]   - max retry          : $TEST_RETRIES"
echo "[${SCRIPT_NAME}]   - interval           : $TEST_INTERVAL"
echo "[${SCRIPT_NAME}]   - connection timeout : $CONNECTION_TIMEOUT"
echo "[${SCRIPT_NAME}]   - post data          : $POST_DATA"
echo
TEST_COUNTER=0
CURL_METHOD=GET
CURL_HEADERS=
CURL_DATA=
if [ ! -z "$POST_DATA" ]; then
  CURL_METHOD=POST
  CURL_HEADERS="Content-Type: application/json"
  CURL_DATA=$POST_DATA
  CURL_POST="--request POST --header \"Content-Type: application/json\" -d \"${POST_DATA}\""
fi
until $(curl --output /dev/null --silent --show-error --insecure --request $CURL_METHOD --header "${CURL_HEADERS}" -d "${CURL_DATA}" --fail --connect-timeout $CONNECTION_TIMEOUT "$TEST_URL"); do
    if [ $TEST_COUNTER -eq $TEST_RETRIES ];then
      echo "${SCRIPT_NAME}][error] max retry reached"
      exit 1
    fi

    echo '  .'
    TEST_COUNTER=$(($TEST_COUNTER+1))
    sleep $TEST_INTERVAL
done
echo "[${SCRIPT_NAME}] website is up."

################################################################################
echo
echo "[${SCRIPT_NAME}] done."
exit 0
