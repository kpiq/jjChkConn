#!/bin/bash
### Make sure this process does not have duplicates.

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR
### Created: June 23, 2023
### Updated: October 25, 2024
### bash script to daemonize the Internet Connectivity Check
### Used as the ExecStart= parameter of the uSysIntChkd@.service
### WHEN INITIATED BY SYSTEMD ALWAYS EXECUTE AS USER ${uUser}.
### USAGE: scriptname

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Global constants
readonly LOGGER="logger"
readonly LOGTAG="-t $(basename ${0})"
declare -A DNS_CACHE
readonly DNS_CACHE_TTL=300  # 5 minutes

# Global temporary file array for cleanup
declare -a TEMPFILES=()

### Define logging functions
log_info() { $LOGGER $LOGTAG -p user.info "$*"; }
log_error() { $LOGGER $LOGTAG -p user.err "$*"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && $LOGGER $LOGTAG -p user.debug "$*"; }

log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && $LOGGER -p user.debug "$*"; }

function create_temp() {
    local tmp
    tmp=$(mktemp) || exit 1
    TEMPFILES+=("$tmp")
    echo "$tmp"
}

function ferror_handler() {
    local line_no="$1"
    local error_code="${2:-1}"
    log_error "Error on line ${line_no}: Failed command: ${BASH_COMMAND}"
    exit "${error_code}"
}

# Enhanced error handling
trap 'ferror_handler ${LINENO}' ERR

### Define fCleanup before using it in the trap statement.
function fCleanup() {
    local uRC=$?
    
    log_info "Cleanup started with exit code: ${uRC}"
    
    # Clean up all temporary files
    if (( ${#TEMPFILES[@]} > 0 )); then
        rm -f "${TEMPFILES[@]}"
    fi
    
    # Remove PID file if it exists
    if [[ -f ${pidfile} ]]; then
        rm -f "${pidfile}"
    fi
    
    # Log exit status
    case ${uRC} in
        0) log_info "Exit through normal exit logic. RC=${uRC}";;
        129) log_info "SIGHUP signal caught. RC=${uRC}";;
        130) log_info "SIGINT signal caught. RC=${uRC}";;
        131) log_info "SIGQUIT signal caught. RC=${uRC}";;
        134) log_info "SIGABRT signal caught. RC=${uRC}";;
        137) log_info "SIGKILL signal caught. RC=${uRC}";;
        143) log_info "SIGTERM signal caught. RC=${uRC}";;
        149) log_info "SIGSTOP signal caught. RC=${uRC}";;
        152) log_info "SIGXCPU signal caught. RC=${uRC}";;
        153) log_info "SIGXFSZ signal caught. RC=${uRC}";;
        154) log_info "SIGVTALRM signal caught. RC=${uRC}";;
        155) log_info "SIGPROF signal caught. RC=${uRC}";;
        156) log_info "SIGPWR signal caught. RC=${uRC}";;
        *) log_info "Unknown signal caught. RC=${uRC}";;
    esac

    log_info "Execution ended"
    exit ${uRC}
}

# Enhanced signal handling
trap fCleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGTERM SIGSTOP SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGPWR EXIT

function resolve_with_cache() {
    local host=$1
    local now
    now=$(date +%s)
    
    if [[ -n "${DNS_CACHE[$host]:-}" ]]; then
        local cached_time=${DNS_CACHE[$host]%%;*}
        local cached_ip=${DNS_CACHE[$host]#*;}
        
        if (( now - cached_time < DNS_CACHE_TTL )); then
            echo "$cached_ip"
            return 0
        fi
    fi
    
    local ip
    ip=$(host -4 "$host" | awk '/has address/ {print $4}' | head -n1)
    DNS_CACHE[$host]="$now;$ip"
    echo "$ip"
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
    return 0
}

function fInit() {
    if [[ -z "${1:-}" ]]; then
        declare -g uUser=jjchkconn
    else
        log_info "User=${1}"
        if id "$1" >/dev/null 2>&1; then
            declare -g uUser=${1}
        else
            log_error "USERNAME ${1} does not exist. Abort..."
            exit 65
        fi
    fi
    
    # Use process substitution to avoid subshell variables
    read -r uUserHome < <(getent passwd "${uUser}" | awk -F: '{print $6}')
    
    if [[ ! -d ${uUserHome} ]]; then
        log_error "HOME Directory ${uUserHome} does not exist. Abort..."
        exit 66
    fi

    ### User runtime directory
    declare -g dir=${uUserHome}/.config/uSysIntChkd

    # Initialize other global variables
    declare -g uCurrOut
    uCurrOut=$(create_temp)
    
    declare -g uIniname
    uIniname=$(basename "${0:0:-5}")
    
    # Redirect output
    exec &> "${dir}/$(echo ${uIniname} | sed 's/\@//g').log"
    
    # Initialize other required variables
    declare -g uConnRC=0
    declare -g uConnStat=ok
    declare -g uCount=0
    declare -g uLossSuspected=false
    declare -g uBeginCountingSeconds=0
    declare -g uEndCountingSeconds=0
    declare -g uHost
    uHost=$(hostname)

    # Call validate_config
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
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

# Fixed loop logic in fTestRC
function fTestRC() {
    local uCurrCat
    uCurrCat=$(fCategorizeuType)
    
    if [[ "$uConnStat" != "ok" ]]; then
        uLossSuspected=true
        log_info "Error: $line failed. Loss of connectivity is possible."
        
        uCount=0
        while [[ "$uLossSuspected" == "true" ]] && (( uCount < uMaxReps )); do
            fIncrementStep
            fSaveStepNum
            fCheckStepNumber
            
            local uNewCat
            uNewCat=$(fCategorizeuType)
            
            if [[ "$uCurrCat" == "$uNewCat" ]]; then
                fReadStepsAndCheck
                if [[ "$uConnStat" != "ok" ]]; then
                    (( uCount++ ))
                else
                    uLossSuspected=false
                    break
                fi
            fi
        done
        
        if [[ "$uLossSuspected" == "true" ]]; then
            fWait4GoodConnection
            fSendAlert
        fi
    fi
}

# Rest of the functions remain similar but with improved error handling
# and logging. Main execution loop:

umask 006

fInit "${1:-}"

source ${dir}/${uIniname}.ini $0

# Use flock for process locking
(
    flock -n 9 || { log_error "Another instance is running"; exit 1; }
    
    while :; do
        fCheckStepNumber
        uConnStat=ok
        fReadStepsAndCheck
        fTestRC
        fIncrementStep
        fSaveStepNum
        sleep "$uSleep"
    done
) 9>"${pidfile}"

exit 0
