#!/bin/sh

### Usage: script /home/username/.config/slack-<botname>.ini "text"

echo "The number of arguments is: $#"

if [ -f "${1}" ] && [ -s "${1}" ];
then
   . "${1}"
   uLog=$(echo "${1}" | sed "s/\.[^.]*$/\.log/")
   echo "\n${uLog}"
else
   echo -e "\n$0: File $1 does not exist.  Abort..."
fi

if [ ! -n "${2}" ];
then
   echo "The text string (2nd argument) is empty"
else
   uText="${0}: "`hostname`"-"`date`"   ${2}"
fi

curl -X POST -F channel=${ChannelID} -F text="${uText}" https://slack.com/api/chat.postMessage -H "Authorization: Bearer ${BotToken}" 2>&1 > ${uLog}

if [ $? -ne 0 ]; then
   echo "$0.  curl Failed.  Abort..."
   cat ${uLog}
   exit 1
fi

if [ -n "${3}" ] && [ -f "${uLog}" ];
then
   echo -e "\nDebug on.  Logfile ${uLog} follows: "
   cat ${uLog}
fi

echo -e "\nRC=$?"
