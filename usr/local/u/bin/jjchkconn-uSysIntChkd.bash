
#!/bin/bash
### Make sure this process does not have duplicates.

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR
### Created: June 23, 2023
### Updated: October 10, 2023
### bash script to daemonize the Internet Connectivity Check
### Used as the ExecStart= parameter of the uSysIntChkd@.service
### WHEN INITIATED BY SYSTEMD ALWAYS EXECUTE AS USER ${uUser}.
### USAGE: scriptname

# ENSURE TRAPS ARE INHERITED BY FUNCTIONS AND OTHERS
set -euo pipefail

readonly LOGGER="logger -t $(basename "$0")"
log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }

function ferror_handler 
{
   echo "$uHost - $(date) - Error occurred."
}

function validate_config() {
    local required_vars=(
        "uUser"
        "uPingCount"
        "uPingSize"
        "uPingWait"
        "uSleep"
        "uMaxReps"
    )
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable $var is not set"
            return 1
        fi
    done
}

function fCategorizeuType() {
    case $uType in
        nu|nt|p|w)
            echo "Type1"
            return 0
            ;;
        dgl|dgn|tr)
            echo "Type2"
            return 0
            ;;
        *)
            echo "Unknown"
            return 1
            ;;
    esac
}

while [ "$uLossSuspected" == "true" ] && [ "$uCount" -lt "$uMaxReps" ]; 
do
   fIncrementStep
   fSaveStepNum
   fCheckStepNumber
   fReadOnly
   uNewCat=$(fCategorizeuType)
   if [[ "$uCurrCat" == "$uNewCat" ]]; then
      fReadStepsAndCheck
      if [[ "$uConnStat" != "ok" ]]; then
         uCount=$((uCount+1))
      else
         uLossSuspected=false
         break
      fi
   fi
done
