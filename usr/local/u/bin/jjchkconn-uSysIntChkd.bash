#!/bin/bash

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR
### Created: June 23, 2023
### Updated: September 8, 2023
### bash script to daemonize the Internet Connectivity Check
### Used as the ExecStart= parameter of the uSysIntChkd@.service
### WHEN INITIATED BY SYSTEMD ALWAYS EXECUTE AS USER ${uUser}.
### USAGE: scriptname

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
         exit 99
      fi
   fi
   
   declare -g uUserHome=`getent passwd ${uUser} | cut -f6 -d:`
   declare -g uGetEntStatus=${PIPESTATUS[0]}
   declare -g uCutStatus=${PIPESTATUS[1]}
   
   exec &> ${uUserHome}/.config/uSysIntChkd/`basename ${0:0:-5} | sed 's/\@//g'`.log
   
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

   declare -g uRC=0
   declare -g uConnRC=0
   declare -g line=""
   declare -g uType=""
   declare -g uSite=""
   declare -g uConnStat=""
   declare -g uCount=0

   ### User runtime directory
   declare -g dir=${uUserHome}/.config/uSysIntChkd

   if [ ! -d ${dir}  ]; then
       echo "$0: Abort.  User runtime directory ${dir} does not exist."
       exit 1
   else
       cd ${dir}
   fi

   source ./`basename ${0:0:-5}`.ini $0

   if [ ${#procs[@]} -gt 1 ]; then
	   echo "Daemon already running (${#procs[@]})"
      exit 2
   fi

   if [ ! -f $pidfile ]; then
      echo $$ > $pidfile
   fi
   
   ### Clean output file before starting execution
   if [ -f ${uOut} ];
   then
      rm ${uOut} 2> /dev/null
   fi

   # Save the total number of lines on the steps_file, as an integer.
   declare -g num_steps=$(awk 'END {print int($1)}' "$steps_file")
}

### Define fCleanup before using it in the trap statement.
function fCleanup()
{
   uRC=$?
   echo `date`;
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

function fValidate()
{
   # Check the steps file
   if [ ! -f $steps_file ];
   then
      echo "Abort.  $steps_file does not exist";
      exit 3
   fi
   
   # Check the step_number file
   declare -g step_number_file="./${uCmd}.next"
   if [ ! -f $step_number_file ];
   then
      echo "Abort.  $step_number_file does not exist";
      exit 4
   fi
   
   # Get the current value of the step number
   declare -g step_number=$(cat $step_number_file)
   
   # Validate the step number
   if ! [[ "${step_number}" =~ ^[0-9]+$ ]]; 
   then
     echo "The step number ("${step_number}") must be a number."
     exit 5
   fi
}

function fSaveStepNum()
{
   # Save the current value of the step number to a file
   echo "${step_number}" > $step_number_file
}

function fCheckStepNumber()
{
   num_steps=`wc -l < "$steps_file"`
   if [ "${step_number}" -lt 1 ] || [ "${step_number}" -gt "${num_steps}" ]; 
   then
      step_number=1
      fSaveStepNum;
   fi
}

function fReadStepsAndCheck()
{
   # Read the steps from the file
   uRC=0
   uConnRC=0
   line=$(sed "${step_number}q;d" "$steps_file")
   if [ -n "$line" ]; then
      echo -e "\n`hostname`-`date`: $0 Executing step ${step_number}"
      uType=`echo $line|cut -f1 -d" "`;
      uSite=`echo $line|cut -f2- -d" "`;
      case ${uType} in
        w)
          wget -t ${uWgetTries} -T ${uWgetTimeout} -O - ${uSite} > $uOut
          uConnRC=$?
          ;;
        p)
          ping -c ${uPingCount} -s ${uPingSize} ${uSite} > $uOut
          uConnRC=$?
          ;;
        nu) # netcat for UDP port
          nc -4 -u -v -z -w ${uWgetTimeout} ${uSite} > $uOut
          uConnRC=$?
          ;;
        nt) # netcat for TCP port
          nc -4 -v -z -w ${uWgetTimeout} ${uSite} > $uOut
          uConnRC=$?
          ;;
        *)
          echo "$0: Error with site ${uSite} in steps file" > $uOut
          ;;
      esac
      uRC=${uConnRC}
   else
      echo "$0: Logic error.  Step ${step_number} not found in ${steps_file}.  Abort..."
      exit 6
   fi
}

function fSendAlert()
{
   if [ "$uConnRC" -ne 0 ]; 
   then
      ### When confirmed down, check for connectivity and issue alert
      uConnStat=down
      echo "`hostname`-`date`: $0 Error: $line failed.  Executing step ${step_number}.  Loss of connectivity is confirmed. `cat $uOut`"
      ### Loop until connectivity returns
      while [ "$uConnRC" -ne 0 ];
      do
         sleep $uPingWait;
         fIncrementStep;
         fSaveStepNum;
         fCheckStepNumber;
         fReadStepsAndCheck;
      done
      ### Connectivity has returned.   Send the alert
      uConnStat=up
      sleep $uPingWait;
      source /usr/local/u/bin/jjchkconn-send-alerts2slack.bash $(whoami) "$0 Error: $line failed.  Loss of connectivity is confirmed. `cat $uOut`"
   fi
}

function fTestRC()
{
   if [ "$uConnRC" -ne 0 ]; then
      echo "`hostname` $0 Error: $line failed.  Loss of connectivity is possible.  `cat $uOut`"
      ### Loss of connectivity is suspected
      uCount=0
      while [ "$uConnRC" -ne 0 ] && [ "$uCount" -lt "$uMaxReps" ]; 
      do
         fIncrementStep;
         fSaveStepNum;
         fCheckStepNumber;
         fReadStepsAndCheck;
	 uCount=$((uCount+1))
      done
      fSendAlert;
   else
      uConnStat=up
   fi
}

function fIncrementStep()
{
   ### Increment to the next step
   step_number=$((step_number + 1))
}
############### FUNCTION DEFINITIONS:  END  ###############

# Trap signals.
trap fCleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGTERM SIGSTOP SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGPWR

umask 006

fInit;
fValidate;

while :
do
   fCheckStepNumber;
   fReadStepsAndCheck;
   fTestRC;
   fIncrementStep;
   fSaveStepNum;
   sleep $uSleep
done

### Perform cleanup before exiting
fCleanup;
exit 0;
