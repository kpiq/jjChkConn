#!/bin/bash

# Validate an IP address
function validate_ip() {
    local uIp=$1
    if [[ $uIp =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        uIp=($uIp)
        IFS=$OIFS
        for i in "${uIp[@]}"; do
            if ! [[ $i =~ ^[0-9]+$ ]] || (( $i < 0 || $i > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

uMsgPfx="$(hostname) - $(date +'%Y/%m/%d @ %H:%M:%S') \"$0\"";

# Get the URL as input
uUrl=$1
if validate_ip "$uUrl"; then
   # $1 is already an ip address
   new_uUrl="$uUrl"
else
   if host -4 $uUrl 2>&1 > /dev/null ; then
      # $1 is a hostname
      uIp=$(host -4 $uUrl | awk '/has address/ {print $4}')

      # Test the ip address
      if validate_ip "$uIp"; then
          true;      #Valid IP address
      else
          echo "$uMsgPfx : ERROR... Invalid IP address \"$uIp\" for FQDN $uUrl.  Abort..."
          exit 94
      fi
      # Create a new URL with the IP address and uPath
      new_uUrl="$uIp"
   else
      # $1 is a url that has at least a scheme and fqdn
      # Extract the Scheme, FQDN, and path from the URL
      uScheme=$(echo $uUrl | awk -F '://' '{print $1}')
      uFqdn=$(echo $uUrl | awk -F '://' '{print $2}' | awk -F '/' '{print $1}')
      uPath=$(echo $uUrl | awk -F '://' '{split($2,a,"/"); if (length(a)>1) {for (i=2;i<=length(a);i++) {if (i>2) printf("/"); printf("%s",a[i])}; print ""}}')

      # extract the port number, if one exists
      uPort=$(echo $uFqdn | awk -F ':' '{print $2}')

      # remove the port number from the fqdn
      uFqdn=$(echo $uFqdn | awk -F ':' '{print $1}')
      
      # Get the IP address of the FQDN
      uIp=$(host -4 $uFqdn | awk '/has address/ {print $4}')
      
      # Test the ip address
      if validate_ip "$uIp"; then
          true;      #Valid IP address
      else
          echo "$uMsgPfx : ERROR... Invalid IP address \"$uIp\" for FQDN $uFqdn.  Abort..."
          exit 95
      fi
      # reassemble the URL with the port number
      if [ -n "$uPort" ]; then
         new_uUrl="$uScheme://$uIp:$uPort/$uPath"
      else
         new_uUrl="$uScheme://$uIp/$uPath"
      fi
      # Create a new URL with the IP address and uPath
   fi
fi

# Print the new URL
echo $new_uUrl
