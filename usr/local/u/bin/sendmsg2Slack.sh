#!/bin/bash
# Improved sendmsg2Slack.sh
set -euo pipefail

readonly LOGGER="logger -t $(basename "$0")"
log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }

# Temporary file handling
declare -g TEMPFILES=()
trap 'rm -f "${TEMPFILES[@]}"' EXIT

function create_temp() {
    local tmp
    tmp=$(mktemp) || exit 1
    TEMPFILES+=("$tmp")
    echo "$tmp"
}

function validate_config() {
    local config_file=$1
    local required_vars=("ChannelID" "BotToken")
    
    if [[ ! -f "$config_file" ]] || [[ ! -s "$config_file" ]]; then
        log_error "Config file '$config_file' does not exist or is empty"
        return 1
    }
    
    # Source config in subshell to avoid polluting environment
    (
        . "$config_file"
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                log_error "Required variable $var is not set in config"
                return 1
            fi
        done
    )
}

function send_slack_message() {
    local config_file=$1
    local message=$2
    local debug=${3:-false}
    
    local log_file
    log_file=$(create_temp)
    
    # Source config file
    . "$config_file"
    
    local formatted_message
    formatted_message="$(basename "$0"): $(hostname)-$(date): $message"
    
    # Use --fail to make curl exit with non-zero on HTTP errors
    if ! curl --fail -X POST \
        -F "channel=${ChannelID}" \
        -F "text=${formatted_message}" \
        -H "Authorization: Bearer ${BotToken}" \
        https://slack.com/api/chat.postMessage \
        2>&1 > "$log_file"; then
        
        log_error "Failed to send message to Slack"
        cat "$log_file" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        log_info "Debug output from Slack API:"
        cat "$log_file"
    fi
    
    return 0
}

function main() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: $0 <config_file> <message> [debug]"
        exit 1
    fi
    
    local config_file=$1
    local message=$2
    local debug=${3:-false}
    
    if ! validate_config "$config_file"; then
        exit 1
    fi
    
    if [[ -z "$message" ]]; then
        log_error "Message cannot be empty"
        exit 1
    fi
    
    if ! send_slack_message "$config_file" "$message" "$debug"; then
        exit 1
    fi
    
    log_info "Message sent successfully"
}

main "$@"
