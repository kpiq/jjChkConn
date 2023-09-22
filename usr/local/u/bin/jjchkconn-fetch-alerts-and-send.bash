#!/bin/bash

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

ALERTSUSER=${uUser}

uUserHome=`getent passwd ${ALERTSUSER}|cut -f6 -d:`
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

# Set the lock file name
if [ $? -ne 0 ];
then
   echo "$0: HOME Directory ${uUserHome} does not exist.  Abort..."
   exit 3
fi
ALERTSFILE=${uUserHome}/alerts/inbound-alerts
LOCKFILE=${ALERTSFILE}.userlock

if [ ! -f ${ALERTSFILE} ];
then
   echo "$0. ${ALERTSFILE} does not exist. Aborting..."
   exit 4
fi

# Check if the lock file exists
if [ ! -f $LOCKFILE ]; then
    # Create the lock file
    touch $LOCKFILE
    echo "$0: Lock file $LOCKFILE created"
else
    # Retry 10 times
    for i in {1..10}; do
        echo "$0: Lock file exists. Waiting for 1 second before retrying..."
        sleep 1
        if [ ! -f $LOCKFILE ]; then
            # Create the lock file
            touch $LOCKFILE 
            echo "$0: Lock file $LOCKFILE created"
            break
        fi
    done
    # If the lock file still exists, stop processing
    if [ -f $LOCKFILE ]; then
        echo "$0: Lock file $LOCKFILE still exists. Stopping processing."
        exit 5
    fi
fi

### SEND ALERTS TO SLACK
bash /usr/local/u/bin/jjchkconn-send-alerts2slack.bash ${ALERTSUSER} "`cat ${ALERTSFILE}`"
if [ $? -ne 0 ]; then
   echo "$0.  Failed to send alert to Slack.  Abort..."
else
   echo "$0.  Alerts sent to slack.com.  Success..."
fi

### CLEANUP
rm ${ALERTSFILE}
if [ $? -ne 0 ]; then
   echo "Abort $0.  Failed to remove data file"
fi
rm ${LOCKFILE}
if [ $? -ne 0 ]; then
   echo "Abort $0.  Failed to remove lock file"
fi
