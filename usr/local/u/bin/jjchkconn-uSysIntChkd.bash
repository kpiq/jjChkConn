#!/bin/bash

exec &> ~/.config/systemd/user/`basename ${0:0:-5} | sed 's/\@//g'`.log

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR
### Created: June 23, 2023
### Updated: June 28, 2023
### bash script to daemonize the Internet Connectivity Check
### Used as the ExecStart= parameter of the uSysIntChkd@.service
### WHEN INITIATED BY SYSTEMD ALWAYS EXECUTE IN THE --user SYSTEMD CONTEXT.
### USAGE: scriptname

### Define fCleanup before using it in the trap statement.
function fCleanup()
{
   if [ -f ${pidfile} ];
   then
      rm ${pidfile}
   fi
   exit 0
}

# Trap signals.
trap fCleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGTERM SIGSTOP SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGPWR


############### FUNCTION DEFINITIONS: BEGIN ###############
function fInit() 
{
   cd ~/.config/uSysIntChkd

   source ./`basename ${0:0:-5}`.ini $0
   
   if [ ! -d $dir ]; then
       echo "$0: Abort.  User runtime directory $dir does not exist."
       exit 1
   fi

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
   declare -g uRC=0
   declare -g line_number=1
   while read -r line; do
       if [ "${step_number}" -eq "${line_number}" ];
       then
          echo -e "\nExecuting step ${step_number}"
          eval "$line" > $uOut
          uRC=$?
       fi
       line_number=$((line_number +1))
   done < "$steps_file"
}

function fSendAlert()
{
   if [ "$uRC" -ne 0 ]; 
   then
      ### When confirmed down, check for connectivity and issue alert
      uConnStat=down
      echo "`hostname` $0 Error: $line failed.  Loss of connectivity is confirmed. `cat $uOut`"
      ### Loop until connectivity returns
      while [ "$uRC" -ne 0 ];
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
      source /usr/local/u/bin/jjchkconn-send-alerts2slack.bash $(whoami) "`hostname` $0 Error: $line failed.  Loss of connectivity is confirmed. `cat $uOut`"
   fi
}

function fTestRC()
{
   if [ "$uRC" -ne 0 ]; then
      echo "`hostname` $0 Error: $line failed.  Loss of connectivity is possible.  `cat $uOut`"
      ### When loss of connectivity is suspected, check connectivity a 2nd time
      fIncrementStep;
      fSaveStepNum;
      fCheckStepNumber;
      fReadStepsAndCheck;
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

### Initialize all variables and validate all files and directories

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