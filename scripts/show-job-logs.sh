#!/bin/sh

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
# This script will show JES job logs
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")

################################################################################
# variables
CI_DEBUG=
CI_ACTION=
CI_ZOSMF_HOST=localhost
CI_ZOSMF_PORT=
CI_ZOSMF_USER=
CI_ZOSMF_PASS=
CI_JOBNAME=
CI_JOBOWNER=*
CI_JOBACTIVE=
CI_JOBID=
CI_FILEID=

# allow to exit by ctrl+c
function finish {
  echo "[${SCRIPT_NAME}] interrupted"
  exit 1
}
trap finish SIGINT


################################################################################
# parse parameters
function usage {
  echo "Show z/OS job logs."
  echo
  echo "Usage: $SCRIPT_NAME [OPTIONS] action"
  echo
  echo "Options:"
  echo "  -h|--help                       display this help message."
  echo "  -d|--debug                      show debug information."
  echo "  -H|--zosmf-host                 z/OSMF host. Default is localhost."
  echo "  -P|--zosmf-port                 z/OSMF port."
  echo "  -u|--zosmf-user                 z/OSMF user."
  echo "  -p|--zosmf-pass                 z/OSMF user password."
  echo "  -n|--jobname                    job name."
  echo "  -o|--jobowner                   job owner. Default is *."
  echo "  -a|--active-only                only show active jobs."
  echo "  -i|--jobid                      job id."
  echo "  -f|--fileid                     file id."
  echo
  echo "Actions:"
  echo "  jobs              list jobs"
  echo "  files             list files of a job"
  echo "  file-content      get content of a file from the job"
  echo "  file-contents     get all file contents from the job"
  echo
  echo "Examples:"
  echo "- show job list with pattern"
  echo "  ./show-job-logs.sh -n 'ZOWE*' jobs"
  echo "- show files of a job"
  echo "  ./show-job-logs.sh -n 'ZOWE1SV' -i ST01234 files"
  echo "- show one file content of a job"
  echo "  ./show-job-logs.sh -n 'ZOWE1SV' -i ST01234 -f 101 file-content"
  echo "- show all file contents of one job"
  echo "  ./show-job-logs.sh -n 'ZOWE1SV' -i ST01234 file-contents"
  echo "- show all file contents of a set of active jobs"
  echo "  ./show-job-logs.sh -n 'ZOWE*' -o IZUSVR -a file-contents"
  echo
}

function call_zosmf_api {
  ENDPOINT=$1

  npx ncc --insecure \
      --user "${CI_ZOSMF_USER}:${CI_ZOSMF_PASS}" \
      https://${CI_ZOSMF_HOST}:${CI_ZOSMF_PORT}/zosmf${ENDPOINT} \
      --headers 'X-CSRF-ZOSMF-HEADER: *'
}

POSITIONALINDEX=0
POSITIONAL[$POSITIONALINDEX]=
while [ $# -gt 0 ]; do
  key="$1"

  case $key in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--debug)
      CI_DEBUG=yes
      shift # past argument
      ;;
    -H|--zosmf-host)
      CI_ZOSMF_HOST="$2"
      shift # past argument
      shift # past value
      ;;
    -P|--zosmf-port)
      CI_ZOSMF_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    -u|--zosmf-user)
      CI_ZOSMF_USER="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--zosmf-pass)
      CI_ZOSMF_PASS="$2"
      shift # past argument
      shift # past value
      ;;
    -n|--jobname)
      CI_JOBNAME="$2"
      shift # past argument
      shift # past value
      ;;
    -o|--jobowner)
      CI_JOBOWNER="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--active-only)
      CI_JOBACTIVE=yes
      shift # past argument
      ;;
    -i|--jobid)
      CI_JOBID="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--fileid)
      CI_FILEID="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      if [ ! "$1" = "${1#-}" ]; then
        echo "[${SCRIPT_NAME}][error] invalid option: $1" >&2
        exit 1
      fi 
      POSITIONAL[$POSITIONALINDEX]="$1" # save it in an array for later
      POSITIONALINDEX=$((POSITIONALINDEX + 1))
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
CI_ACTION=$1

################################################################################
# essential validations

# these are required to run node v8
export _BPXK_AUTOCVT=ON
export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"

NODE_VERSION=$(node --version | cut -c1-3)
if [ "$NODE_VERSION" != "v8." ]; then
  >&2 echo "[${SCRIPT_NAME}][error] this tool requires node.js v8."
  exit 1
fi

if [ -z "$CI_ACTION" ]; then
  >&2 echo "[${SCRIPT_NAME}][error] action is empty."
  exit 1
fi

################################################################################
if [ "${CI_DEBUG}" = "yes" ]; then
  echo "[${SCRIPT_NAME}] action \"${CI_ACTION}\" started ..."
  echo "[${SCRIPT_NAME}]   - z/OSMF host        : $CI_ZOSMF_HOST"
  echo "[${SCRIPT_NAME}]   - z/OSMF port        : $CI_ZOSMF_PORT"
  echo "[${SCRIPT_NAME}]   - z/OSMF user        : $CI_ZOSMF_USER"
  echo "[${SCRIPT_NAME}]   - Job owner          : $CI_JOBOWNER"
  echo "[${SCRIPT_NAME}]   - Job name           : $CI_JOBNAME"
  echo "[${SCRIPT_NAME}]   - Job ID             : $CI_JOBID"
  echo "[${SCRIPT_NAME}]   - File ID            : $CI_FILEID"
  echo
fi

################################################################################
if [ "${CI_DEBUG}" = "yes" ]; then
  echo "[${SCRIPT_NAME}] installing/upgrading node-curl-cli ..."
  npm install curl-cli || true
  npm install jq2 || true
  echo
else
  echo >/dev/null 2>&1
  npm install curl-cli >/dev/null 2>&1
  npm install jq2 >/dev/null 2>&1
fi

################################################################################
case $CI_ACTION in
  jobs)
    # validate
    if [ -z "$CI_JOBNAME" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job name option is required."
      exit 1
    fi

    JOBS=$(call_zosmf_api "/restjobs/jobs?owner=${CI_JOBOWNER}&prefix=${CI_JOBNAME}" | npx jq2 '$.map(s => `${s.jobname},${s.jobid},${s.status}`).join("\n")')
    if [ "${CI_DEBUG}" = "yes" ]; then
      echo "[${SCRIPT_NAME}] job list of ${CI_JOBNAME}:"
      echo
    fi
    for job in $JOBS; do
      echo "${job}"
    done
    ;;
  files)
    # validate
    if [ -z "$CI_JOBNAME" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job name option is required."
      exit 1
    fi
    if [ -z "$CI_JOBID" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job id option is required."
      exit 1
    fi

    FILES=$(call_zosmf_api "/restjobs/jobs/${CI_JOBNAME}/${CI_JOBID}/files" | npx jq2 '$.map(s => `${s.id},${s.ddname}`).join("\n")')
    if [ "${CI_DEBUG}" = "yes" ]; then
      echo "[${SCRIPT_NAME}] files list of ${CI_JOBNAME}-${CI_JOBID}:"
      echo
    fi
    for f in $FILES; do
      echo "${f}"
    done
    ;;
  file-content)
    # validate
    if [ -z "$CI_JOBNAME" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job name option is required."
      exit 1
    fi
    if [ -z "$CI_JOBID" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job id option is required."
      exit 1
    fi
    if [ -z "$CI_FILEID" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] file id option is required."
      exit 1
    fi

    FILE_CONTENT=$(call_zosmf_api "/restjobs/jobs/${CI_JOBNAME}/${CI_JOBID}/files/${CI_FILEID}/records")
    if [ "${CI_DEBUG}" = "yes" ]; then
      echo "[${SCRIPT_NAME}] file ${CI_JOBNAME}-${CI_JOBID}-${CI_FILEID}:"
      echo
    fi
    printf "%s\n" "${FILE_CONTENT}"
    ;;
  file-contents)
    # validate
    if [ -z "$CI_JOBNAME" ]; then
      >&2 echo "[${SCRIPT_NAME}][error] job name option is required."
      exit 1
    fi
    if [ -z "$CI_JOBID" ]; then
      JOBS=$(call_zosmf_api "/restjobs/jobs?owner=${CI_JOBOWNER}&prefix=${CI_JOBNAME}" | npx jq2 '$.map(s => `${s.jobname},${s.jobid}`).join("\n")')
    else
      JOBS="${CI_JOBNAME},${CI_JOBID}"
    fi

    for job in $JOBS; do
      JOBNAME=$(echo $job | awk -F, '{print $1}')
      JOBID=$(echo $job | awk -F, '{print $2}')
      FILES=$(call_zosmf_api "/restjobs/jobs/${JOBNAME}/${JOBID}/files" | npx jq2 '$.map(s => `${s.id},${s.ddname}`).join("\n")')
      if [ "${CI_DEBUG}" = "yes" ]; then
        echo "[${SCRIPT_NAME}] files list of ${JOBNAME}-${JOBID}:"
        echo
      fi
      for f in $FILES; do
        FILE_ID=$(echo $f | awk -F, '{print $1}')
        FILE_NAME=$(echo $f | awk -F, '{print $2}')
        FILE_CONTENT=$(call_zosmf_api "/restjobs/jobs/${JOBNAME}/${JOBID}/files/${FILE_ID}/records")
        if [ "${CI_DEBUG}" = "yes" ]; then
          echo "[${SCRIPT_NAME}] file ${JOBNAME}-${JOBID} (${FILE_ID}-${FILE_NAME}):"
          echo
        else
          echo "===========================${JOBNAME}-${JOBID}-${FILE_NAME}=============================="
        fi
        printf "%s\n" "${FILE_CONTENT}"
        if [ "${CI_DEBUG}" = "yes" ]; then
          echo
        fi
      done
    done
    ;;
  *)
    >&2 echo "[${SCRIPT_NAME}][error] unsupported action $CI_ACTION."
    exit 1
    ;;
esac

################################################################################
if [ "${CI_DEBUG}" = "yes" ]; then
  echo
  echo "[${SCRIPT_NAME}] done."
fi
exit 0
