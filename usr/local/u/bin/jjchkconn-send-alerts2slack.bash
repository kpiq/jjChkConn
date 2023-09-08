#!/bin/bash

declare -g uUser=jjchkconn
exec &> ~${uUser}/.config/uSysIntChkd/`basename ${0:0:-5} | sed 's/\@//g'`.log

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR, USA
### USAGE: scriptname username "message"
### DEPENDENCY: file called $uIniFile (see below).  Must
###		contain one line starting with exactly: "WebHook="
###		followed by the Slack WebHook URL.

if [ $# -ne 2 ]; then
   echo "Abort.  The number of arguments must be strictiy two (2).";
   echo "	 If passing arguments with whitespaces enclose text in quotes.";
   exit 1;
fi

uUser=$1
uHomeDir=`getent passwd $uUser|cut -f6 -d:`
uIniFile="$uHomeDir/.config/jjchkconn-slack-alerts.ini"

if [ -f "$uIniFile" ];
then
   uWebHook=`grep WebHook "$uIniFile"|cut -f2 -d=`
else
   echo "Abort.  "$uIniFile" does not exist"
   exit 2
fi

### In case attachments are desired use the following format:
###	curl -X POST -H 'Content-type: application/json' -F 'file=@somefile1.txt' -F 'file=@somefile2.txt' http://someurl
if [ -s "${2}" ];
then
   jq -Rs '{text: .}' "${2}" | curl -X POST -H 'Content-type: application/json' -d @- $uWebHook
else
   curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${2}\"}" $uWebHook
fi
