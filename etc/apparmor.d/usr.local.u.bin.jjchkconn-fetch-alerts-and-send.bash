# Last Modified: Fri Sep  8 20:04:27 2023
abi <abi/3.0>,

include <tunables/global>

/usr/local/u/bin/jjchkconn-fetch-alerts-and-send.bash {
  include <abstractions/base>
  include <abstractions/bash>
  include <abstractions/consoles>
  include <abstractions/lightdm>

  capability dac_read_search,

  /usr/bin/basename px,
  /usr/bin/bash ix,
  /usr/bin/curl mrix,
  /usr/bin/cut mrix,
  /usr/bin/getent mrix,
  /usr/bin/grep mrix,
  /usr/bin/id Px,
  /usr/bin/jq mrix,
  /usr/bin/sed mrix,
  /home/jjchkconn/** rw,
  /home/jjchkconn/**/* rw,
  /usr/local/u/bin/** mrwix,
  /usr/local/u/bin/**/* mrwix,
#  /usr/local/u/bin/jjchkconn-fetch-alerts-and-send.bash mrwix,
  owner /home/*/.config/jjchkconn-slack-alerts.ini r,
  owner /proc/*/maps r,
  owner /proc/filesystems r,

}
