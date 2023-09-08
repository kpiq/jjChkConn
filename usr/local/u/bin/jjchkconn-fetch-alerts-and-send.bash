#!/bin/bash

declare -g uUser=jjchkconn
exec &> ~${uUser}/.config/uSysIntChkd/`basename ${0:0:-5} | sed 's/\@//g'`.log

# Set the lock file name
ALERTSUSER=$(whoami)
ALERTSHOME=`getent passwd ${ALERTSUSER}|cut -f6 -d:`
if [ $? -ne 0 ];
then
   echo "$0: HOME Directory ${ALERTSHOME} does not exist.  Abort..."
   exit 1
fi
ALERTSFILE=${ALERTSHOME}/alerts/inbound-alerts
LOCKFILE=${ALERTSFILE}.lock

if [ ! -f ${ALERTSFILE} ];
then
   echo "$0. ${ALERTSFILE} does not exist. Aborting..."
   exit 2
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
        exit 3
    fi
fi

### SEND ALERTS TO SLACK
/usr/local/u/bin/${uUser}-send-alerts2slack.bash ${ALERTSUSER} "`cat ${ALERTSFILE}`"
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
rm ${ALERTSFILE}.lock
if [ $? -ne 0 ]; then
   echo "Abort $0.  Failed to remove lock file"
fi
