#!/bin/bash

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR, USA
### USAGE: scriptname username "message"
### DEPENDENCY: file called $uIniFile (see below).  Must
###		contain one line starting with exactly: "WebHook="
###		followed by the Slack WebHook URL.

if [ -z "${1}" ];
then
   declare -g uUser=jjchkconn
else
   echo "$0: User=${1}"
   if id "$1" >/dev/null 2>&1;
   then
      declare -g uUser=${1}
   else
      echo "$0: USERNAME ${1} does not exist.  Abort..."
      exit 99
   fi
fi

declare -g uUserHome=`getent passwd ${uUser} | cut -f6 -d:`
exec &> ${uUserHome}/.config/uSysIntChkd/`basename ${0:0:-5} | sed 's/\@//g'`.log
declare -g uGetEntStatus=${PIPESTATUS[0]}
declare -g uCutStatus=${PIPESTATUS[1]}

if [[ ${uGetEntStatus} -eq 0 ]] && [[ ${uCutStatus} -eq 0 ]];
then
   ### HOME Directory is properly configured for this user. ###
   ### Now test whether it exists. ###
   if [ ! -d ${uUserHome} ];
   then
      echo "$0: HOME Directory ${uUserHome} does not exist.  Abort..."
      exit 1
   fi
else
   echo -e "\n$0: getent exit code = ${uGetEntStatus}"
   echo -e "\n$0: cut exit code = ${uCutStatus}"
   echo "$0: HOME Directory ${uUserHome} not properly configured for this user.  Abort..."
   exit 2
fi

exec &> ${uUserHome}/.config/uSysIntChkd/`basename ${0:0:-5} | sed 's/\@//g'`.log

if [ $# -ne 2 ]; then
   echo "Abort.  The number of arguments must be strictiy two (2).";
   echo "	 If passing arguments with whitespaces enclose text in quotes.";
   exit 3;
fi

uHomeDir=`getent passwd $uUser|cut -f6 -d:`
uIniFile="$uHomeDir/.config/jjchkconn-slack-alerts.ini"

if [ -f "$uIniFile" ];
then
   uWebHook=`grep WebHook "$uIniFile"|cut -f2 -d=`
else
   echo "Abort.  "$uIniFile" does not exist"
   exit 4
fi

### In case attachments are desired use the following format:
###	curl -X POST -H 'Content-type: application/json' -F 'file=@somefile1.txt' -F 'file=@somefile2.txt' http://someurl
if [ -s "${2}" ];
then
   jq -Rs '{text: .}' "${2}" | curl -X POST -H 'Content-type: application/json' -d @- $uWebHook
else
   curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${2}\"}" $uWebHook
fi
