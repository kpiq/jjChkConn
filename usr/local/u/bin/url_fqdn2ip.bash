#!/bin/bash
# Improved url_fqdn2ip.bash
set -euo pipefail

readonly LOGGER="logger -t $(basename "$0")"
log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }

# DNS caching implementation
declare -A DNS_CACHE
DNS_CACHE_TTL=300  # 5 minutes

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
    ip=$(host -4 "$host" | awk '/has address/ {print $4}' | shuf | head -n1)
    DNS_CACHE[$host]="$now;$ip"
    echo "$ip"
}

function validate_ip() {
    local ip=$1
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $ip_regex ]]; then
        return 1
    fi
    
    local IFS='.' read -ra ADDR <<< "$ip"
    for octet in "${ADDR[@]}"; do
        if (( octet < 0 || octet > 255 )); then
            return 1
        fi
    done
    return 0
}

function parse_url() {
    local url=$1
    local -n result=$2  # nameref to pass results back
    
    # Extract components using more reliable parsing
    if [[ $url =~ ^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$ ]]; then
        result[scheme]=${BASH_REMATCH[2]:-}
        local authority=${BASH_REMATCH[4]:-}
        result[path]=${BASH_REMATCH[5]:-}
        
        # Parse authority (host:port)
        if [[ $authority =~ ^([^:]+)(:([0-9]+))?$ ]]; then
            result[host]=${BASH_REMATCH[1]}
            result[port]=${BASH_REMATCH[3]:-}
        fi
    else
        log_error "Invalid URL format: $url"
        return 1
    fi
}

function main() {
    if [[ $# -ne 1 ]]; then
        log_error "Usage: $0 <url_or_ip>"
        exit 1
    fi
    
    local url=$1
    declare -A url_parts
    
    if validate_ip "$url"; then
        echo "$url"
        return 0
    fi
    
    if [[ $url =~ ^[^:/]+$ ]]; then
        # Simple hostname
        local ip
        ip=$(resolve_with_cache "$url")
        if ! validate_ip "$ip"; then
            log_error "Invalid IP address '$ip' resolved from hostname '$url'"
            exit 1
        fi
        echo "$ip"
        return 0
    fi
    
    # Handle full URL
    parse_url "$url" url_parts
    
    if [[ -z "${url_parts[host]:-}" ]]; then
        log_error "Could not extract hostname from URL: $url"
        exit 1
    fi
    
    local ip
    ip=$(resolve_with_cache "${url_parts[host]}")
    
    if ! validate_ip "$ip"; then
        log_error "Invalid IP address '$ip' resolved from hostname '${url_parts[host]}'"
        exit 1
    fi
    
    # Reconstruct URL with IP
    local new_url="${url_parts[scheme]}://$ip"
    if [[ -n "${url_parts[port]:-}" ]]; then
        new_url+=":${url_parts[port]}"
    fi
    if [[ -n "${url_parts[path]:-}" ]]; then
        new_url+="${url_parts[path]}"
    fi
    
    echo "$new_url"
}

main "$@"
