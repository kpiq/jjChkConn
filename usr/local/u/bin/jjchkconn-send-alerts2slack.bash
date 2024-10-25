
#!/bin/bash

set -euo pipefail

### Author: Pedro Serrano, jj10 Net LLC, Bayamon, PR, USA
### USAGE: scriptname username "message"

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

readonly LOGGER="logger -t $(basename "$0")"
log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }

# Slack API call with enhanced error handling
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST --data-urlencode "payload=$payload" "$webhook_url")
if [[ "$response" -ne 200 ]]; then
    log_error "Failed to send message to Slack. HTTP status code: $response"
    exit 1
fi
