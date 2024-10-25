
#!/bin/bash

set -euo pipefail

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

uUserHome=$(getent passwd ${ALERTSUSER}|cut -f6 -d:)
exec &> ${uUserHome}/.config/uSysIntChkd/$(basename "${0:0:-5}" | sed 's/@//g').log

readonly LOGGER="logger -t $(basename "$0")"
log_info() { $LOGGER -p user.info "$*"; }
log_error() { $LOGGER -p user.err "$*"; }

# Locking mechanism using flock
(
    flock -n 9 || exit 1
    # Critical section here
) 9>"${LOCKFILE}"

# Temporary file handling
declare -g TEMPFILES=()
trap 'rm -f "${TEMPFILES[@]}"' EXIT

function create_temp() {
    local tmp
    tmp=$(mktemp) || exit 1
    TEMPFILES+=("$tmp")
    echo "$tmp"
}
