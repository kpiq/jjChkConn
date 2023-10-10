#!/bin/bash
### Make sure this process does not have duplicates.

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR
### Created: June 23, 2023
### Updated: October 7, 2023
### bash script to daemonize the Internet Connectivity Check
### Used as the ExecStart= parameter of the uSysIntChkd@.service
### WHEN INITIATED BY SYSTEMD ALWAYS EXECUTE AS USER ${uUser}.
### USAGE: scriptname

# ENSURE TRAPS ARE INHERITED BY FUNCTIONS AND OTHERS
set -E

function ferror_handler 
{
   echo "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error on line ${LINENO}: Failed command: $(eval "${BASH_COMMAND}")"
#   exit 64
}

trap ferror_handler ERR

### Define fCleanup before using it in the trap statement.
function fCleanup()
{
   uRC=$?
   set -xv
   echo "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error on line ${LINENO}. Failed command: $(eval "${BASH_COMMAND}")"
   set +xv
   echo `date +"%Y-%m-%d %H:%M:%S"`;
   case ${uRC} in
      0) echo "Exit thru normal exit logic.  RC=${uRC}";;
      129) echo "SIGHUP signal caught.  RC=${uRC}";;
      130) echo "SIGINT signal caught.  RC=${uRC}";;
      131) echo "SIGQUIT signal caught.  RC=${uRC}";;
      134) echo "SIGABRT signal caught.  RC=${uRC}";;
      137) echo "SIGKILL signal caught.  RC=${uRC}";;
      143) echo "SIGTERM signal caught.  RC=${uRC}";;
      149) echo "SIGSTOP signal caught.  RC=${uRC}";;
      152) echo "SIGXCPU signal caught.  RC=${uRC}";;
      153) echo "SIGXFSZ signal caught.  RC=${uRC}";;
      154) echo "SIGVTALRM signal caught.  RC=${uRC}";;
      155) echo "SIGPROF signal caught.  RC=${uRC}";;
      156) echo "SIGPWR signal caught.  RC=${uRC}";;
      *) echo "Unknown signal caught.  RC=${uRC}";;
   esac

   if [ -f ${pidfile} ];
   then
      rm ${pidfile}
   fi

   ### Debugging logic.  Find out where the program failed.   
   echo "$0: Listing all function names in the FUNCNAME array";
   # List all function names in FUNCNAME array
   for func in "${FUNCNAME[@]}"; do
     echo "$func"
   done

   exit ${uRC}
}

# Trap signals.
trap fCleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGTERM SIGSTOP SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGPWR

############### FUNCTION DEFINITIONS: BEGIN ###############
function fInit() 
{
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
         exit 65
      fi
   fi
   
   declare -g uUserHome=`getent passwd ${uUser} | awk -F: '{print $6}'`
   declare -g uGetEntStatus=${PIPESTATUS[0]}
   declare -g uCutStatus=${PIPESTATUS[1]}

   ### Init file to be used strictly for the current stdout message
   ### and be cleared one the next step arrives.
   uCurrOut=$(mktemp)

   ### Prefix of script being executed
   declare -g uIniname=`basename ${0:0:-5}`
   
   exec &> ${uUserHome}/.config/uSysIntChkd/$(echo ${uIniname} | sed 's/\@//g').log
   
   if [[ ${uGetEntStatus} -eq 0 ]] && [[ ${uCutStatus} -eq 0 ]];
   then
      ### HOME Directory is properly configured for this user. ###
      ### Now test whether it exists. ###
      if [ ! -d ${uUserHome} ];
      then
         echo "$0: HOME Directory ${uUserHome} does not exist.  Abort..."
         exit 66
      fi
   else
      echo -e "\n$0: getent exit code = ${uGetEntStatus}"
      echo -e "\n$0: cut exit code = ${uCutStatus}"
      echo "$0: HOME Directory ${uUserHome} not properly configured for this user.  Abort..."
      exit 67
   fi

   declare -g uRC=0
   declare -g uConnRC=0
   declare -g line=""
   declare -g uType=""
   declare -g uSite=""
   ### Connectivity Status
   declare -g uConnStat=ok
   declare -g uCount=0
   declare -g uActualPktLoss=0
   declare -g uActualRTT=1
   declare -g uGrepStatus=0
   declare -gi uActual=0
   declare -gi uTestResult=0
   declare -gi uAcceptable=0
   declare -g uLossPossible=false
   declare -g uLossConfirmed=false

   ### uAcceptableLatency and uAcceptableLoss are only required for 
   ### step-type indicators dgn, dgl, and tr.
   ### uAcceptableLatency in ms
   ### uAcceptableLoss in %
   declare -gi uAcceptableLatency=2
   declare -gi uAcceptableLoss=3

   ### User runtime directory
   declare -g dir=${uUserHome}/.config/uSysIntChkd

   if [ ! -d ${dir}  ]; then
       echo "$0: Abort.  User runtime directory ${dir} does not exist."
       exit 68
   else
       cd ${dir}
   fi

   declare -g pidfile="${dir}/${uIniname}.pid"

   ## Output of this script will be redirected to this file
   declare -g uOut="${dir}/${uIniname}.output"

   declare -gi num_steps=0
   declare -g steps_file_on_disk="${dir}/${uIniname}.steps"
   declare -g steps_file=$(mktemp)
   fGetStepsFile;

   ### $dir is used in the .ini file.  Do not move the following statement
   ### without moving the user runtime declaration with it.
   source ${dir}/${uIniname}.ini $0

   ### Make sure this process does not have duplicates.
   ### Check if the daemon is already running.
   declare -g procs=`pgrep -c -f $(basename $(echo $0|sed 's/^-//g'))`
   if [ "${procs}" -gt 2 ]; then
      echo "Daemon already running (${procs})"
      exit 69
   fi

   if [ ! -f $pidfile ]; then
      echo $$ > $pidfile
   fi
   
   ### Clean output file before starting execution
   if [ -f ${uOut} ];
   then
      echo > "${uOut}"
   fi
}

function fGetStepsFile()
{
   # Get the steps file.  Get rid of all comment lines, 
   # empty lines, or lines that only contain whitespace(s).
   # Always fetch file from disk in order to get any updates that are
   # made while the program is running.
   awk '!/^[[:space:]]*($|#)/ && NF' $steps_file_on_disk > $steps_file
   # Save the total number of lines on the steps_file, as an integer.
   num_steps=$(awk 'END {print int(NR)}' "$steps_file")
}

function fValidate()
{
   # Check the steps file
   if [ ! -f $steps_file ];
   then
      echo "Abort.  $steps_file does not exist";
      exit 70
   fi
   
   # Check the step_number file
   declare -g step_number_file="${dir}/${uIniname}.next"
   if [ ! -f $step_number_file ];
   then
      echo "Abort.  $step_number_file does not exist";
      exit 71
   fi
   
   # Get the current value of the step number
   declare -g step_number=$(cat $step_number_file)
   
   # Validate the step number
   if ! [[ "${step_number}" =~ ^[0-9]+$ ]]; 
   then
     echo "The step number ("${step_number}") must be a number."
     exit 72
   fi
}

function fSaveStepNum()
{
   # Save the current value of the step number to a file
   echo "${step_number}" > $step_number_file
}

function fCheckStepNumber()
{
   # Reinitialize step_number if it falls out of range
   if [ "${step_number}" -lt 1 ] || [ "${step_number}" -gt "${num_steps}" ]; 
   then
      step_number=1
      fSaveStepNum;
   fi
}

function fEvalResults()
{
   uTmpfile=$(mktemp);  cp -a $uCurrOut $uTmpfile; 
   uActual=0
   uTestResult=0
   uAcceptable=0
   uActualPktLoss=0
   uActualRTT=0
   declare -g uLossOrLatency=false

   # EVALUATE PACKET LOSS
   uActualPktLoss=$(sed -n '/packets transmitted/p' $uTmpfile|awk '{print $6}'|tr -d "%")
   if [ -z "${uActualPktLoss}" ];
   then
      echo "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error.  For $uSite, Packet information is not present.  Check for logic error or true anomaly."  >> $uOut
   else
      declare -i uActual=$(awk '{print int($uActualPktLoss)}' <<< "$uActualPktLoss")
      declare -i uAcceptable=$(awk '{print int($uAcceptableLoss)}' <<< "$uAcceptableLoss")
      if [ ${uActual} -gt ${uAcceptable} ];
      then
	 echo -e "\n`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: For $uSite, Packet loss of ${uActual}% is unacceptable.   Acceptable maximum is ${uAcceptable}%" >> $uOut
         uConnStat="PACKET LOSS"
	 uLossOrLatency=true
      fi
   fi

   # EVALUATE LATENCY
   uActualRTT=$(sed -n '/^rtt[[:space:]]*min/p' $uTmpfile|awk -F/ '{print $5}')
   if [ -z "${uActualRTT}" ];
   then
      echo "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error.  For $uSite, RTT information is not present.  Check for logic error or true anomaly."  >> $uOut
   else
      declare -i uActual=$(awk '{print int($uActualRTT)}' <<< "$uActualRTT")
      declare -i uAcceptable=$(awk '{print int($uAcceptableLatency)}' <<< "$uAcceptableLatency")
      if [ ${uActual} -gt ${uAcceptable} ];
      then
	 echo -e "\n`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: For $uSite, Latency is unacceptable: ${uActual}ms.   Acceptable maximum is ${uAcceptable}ms." >> $uOut
         uConnStat="HIGH LATENCY"
	 uLossOrLatency=true
      fi
   fi
   rm $uTmpfile
   if [[ "$uLossOrLatency" == "false" ]];
   then
      uConnStat=ok
   fi
}

function fReadOnly()
{
   line=$(sed "${step_number}q;d" "$steps_file")
   uType=`echo $line|awk '{print $1}'`;
}

function fReadStepsAndCheck()
{
   # Read the steps from the file
   uRC=0
   uConnRC=0
   line=$(sed "${step_number}q;d" "$steps_file")
   
   ### Clear the Current step Output file.
   echo > $uCurrOut

   echo -e "\n`hostname`-`date +"%Y-%m-%d %H:%M:%S"`: $0 Executing step ${step_number}"
   uType=`echo $line|awk '{print $1}'`;
   case ${uType} in
     w) # wget
       uSite=`echo $line|awk '{print $2}'`;
       wget -t ${uWgetTries} -T ${uWgetTimeout} -O - ${uSite} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       ;;
     p) # ping, without checking packet loss or latency
       uSite=`echo $line|awk '{print $2}'`;
       ping -c ${uPingCount} -s ${uPingSize} ${uSite} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       ;;
     nu) # netcat for UDP port
       uSite=`echo $line|awk '{print $2}'`;
       uAcceptableLatency=`echo $line|awk '{print $3}'`;
       uPortNum=${uAcceptableLatency}
       nc -4 -u -v -z -w ${uWgetTimeout} ${uSite} ${uPortNum} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       ;;
     nt) # netcat for TCP port
       uSite=`echo $line|awk '{print $2}'`;
       uAcceptableLatency=`echo $line|awk '{print $3}'`;
       uPortNum=${uAcceptableLatency}
       nc -4 -v -z -w ${uWgetTimeout} ${uSite} ${uPortNum} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       ;;
     dgn) # Check connection to Network Default Gateway
       uSite=`echo $line|awk '{print $2}'`;
       uAcceptableLatency=`echo $line|awk '{print $3}'`;
       uAcceptableLoss=`echo $line|awk '{print $4}'`;
       if [ ${uPingCount} -lt 3 ]; then
          uPingCount=3
       fi
       # FOR THIS OPERATION DON'T APPEND, OVERWRITE THE CURRENT STEP OUTPUT
       ping -c ${uPingCount} ${uSite} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       fEvalResults
       ;;
     dgl) # Check local host's Default Gateway. Accept multiple gw's.
       uSite=`echo $line|awk '{print $2}'`;
       uAcceptableLatency=1;
       uAcceptableLoss=0;
       if [ ${uPingCount} -lt 3 ]; then
          uPingCount=3
       fi
       # Deal with the possibility of multiple Default Gateways.
       # No site argument in steps_file. Derive it using `ip route`.
       readarray -t uSiteArray < <(ip route | awk '/^default/ {print $3}')
       echo "There are ${#uSiteArray[@]} default gateways on this system." >> $uOut
       if [ "${#uSiteArray[@]}" -lt 1 ]; then
          echo -e "\n`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error.  System does not have a default route." >> $uOut
       fi
       for uSite in "${uSiteArray[@]}"
       do
          # FOR THIS OPERATION DON'T APPEND, OVERWRITE THE CURRENT STEP OUTPUT
          ping -c ${uPingCount} ${uSite} |tee $uCurrOut >> $uOut
          uConnRC=${PIPESTATUS[0]}
          if [ "$uConnRC" -ne 0 ]; then
             uConnStat=notok
          else
             uConnStat=ok
          fi
          fEvalResults
       done
       ;;
     tr) # Check connection to transit node 
       uSite=`echo $line|awk '{print $2}'`;
       uAcceptableLatency=`echo $line|awk '{print $3}'`;
       uAcceptableLoss=`echo $line|awk '{print $4}'`;
       if [ ${uPingCount} -lt 3 ]; then
          uPingCount=3
       fi
       # FOR THIS OPERATION DON'T APPEND, OVERWRITE THE CURRENT STEP OUTPUT
       ping -c ${uPingCount} ${uSite} |tee $uCurrOut >> $uOut
       uConnRC=${PIPESTATUS[0]}
       if [ "$uConnRC" -ne 0 ]; then
          uConnStat=notok
       else
          uConnStat=ok
       fi
       fEvalResults
       ;;
     *)
       echo "$0: Error with site definition for ${uSite} in steps file" >> $uOut
       ;;
   esac
   uRC=${uConnRC}
}

function fWait4GoodConnection
{
   ### When confirmed down, check for connectivity before issuing alert
   echo "`hostname`-`date +"%Y-%m-%d %H:%M:%S"`: $0 Error: $line failed.  Executing step ${step_number}.  Loss of connectivity is confirmed. `cat $uCurrOut`" >> $uOut

   ### Wait until connectivity returns
   while [ "$uConnStat" != "ok" ];
   do
      sleep $uPingWait;
      fIncrementStep;
      fSaveStepNum;
      fCheckStepNumber;
      fReadStepsAndCheck;
   done
   ### Connectivity has returned.
}

function fSendAlert()
{
   ### Connectivity has returned.   Send the alert
   echo -e "\n\n`hostname`-`date +"%Y-%m-%d %H:%M:%S"`: $0 Getting ready to send alert to Slack"
   sleep $uSleepAfterOK;

   source /usr/local/u/bin/jjchkconn-send-alerts2slack.bash ${uUser} "$0 Error: $line failed.  Loss of connectivity is confirmed. `cat $uCurrOut`"
}

function fCategorizeuType()
{
   case $uType in
        nu|nt|p|w)
           return "Type1"
           ;;
        dgl|dgn|tr)
           return "Type2"
           ;;
        *)
           return "Unknown"
	   echo -e "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0: Error in line ${LINENO}.  Unknown uType=$uType" >> $uOut
           ;;
   esac
}
function fTestRC()
{
   # Categorize the last uType so that the confirmation only matches against
   # the same category of steps.  
   #	Type1 steps are w, p, nu, and nt.
   #	Type2 steps are dgl, dgn, and tr.
   uCurrCat=fCategorizeuType;
   if [[ "$uConnStat" != "ok" ]]; 
   then
      uLossPossible=true
      uLossConfirmed=false
      echo "`hostname` - `date +"%Y-%m-%d %H:%M:%S"` $0 Error: $line failed.  Loss of connectivity is possible.  `cat $uCurrOut`"
      ### Loss of connectivity is suspected. 
      ### Loop to confirm the loss.
      uCount=0
      while [ "$uLossPossible" == "true" ] && [ "$uCount" -lt "$uMaxReps" ]; 
      do
         fIncrementStep;
         fSaveStepNum;
         fCheckStepNumber;
	 # Read ahead, extract the new uType, but don't increment or 
         # do anything else. Then categorize the new Steps type.
	 fReadOnly;
         uNewCat=fCategorizeuType;
	 if [[ "$uCurrCat" == "$uNewCat" ]]; then
            fReadStepsAndCheck;
	    if [[ "$uConnStat" != "ok" ]]; 
	    then
               uLossConfirmed=true
	       uCount=$((uCount+1))
	       # To exit the loop, reinit uLossPossible
               uLossPossible=false
	    fi
         fi
      done
      if [ "$uLossConfirmed" == "true" ]; 
      then
	 fWait4GoodConnection;
         fSendAlert;
      fi
      uLossPossible=false
   fi
}

function fIncrementStep()
{
   ### Increment to the next step
   step_number=$((step_number + 1))
}
############### FUNCTION DEFINITIONS:  END  ###############

umask 006

fInit;
fValidate;

while :
do
   fCheckStepNumber;
   uConnStat=ok
   fReadStepsAndCheck;
   fTestRC;
   fIncrementStep;
   fSaveStepNum;
   sleep $uSleep
done

### Perform cleanup before exiting
fCleanup;
exit 0;
