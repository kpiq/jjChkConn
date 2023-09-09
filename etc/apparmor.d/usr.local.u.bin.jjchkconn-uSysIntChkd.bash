# Last Modified: Fri Sep  8 20:14:05 2023
abi <abi/3.0>,

include <tunables/global>

/usr/local/u/bin/jjchkconn-uSysIntChkd.bash {
  include <abstractions/base>
  include <abstractions/bash>
  include <abstractions/consoles>
  include <abstractions/lightdm>

  /home/*/.config/jjchkconn-slack-alerts.ini r,
  /proc/*/cmdline r,
  /proc/filesystems r,
  /proc/sys/kernel/random/boot_id r,
  /usr/bin/basename mrix,
  /usr/bin/bash ix,
  /usr/bin/sed mrix,
  /usr/local/u/bin/jjchkconn-uSysIntChkd.bash r,
  /{,var/}run/** mrwk,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.ini r,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.log w,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.next r,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.next w,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.output r,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.output w,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.pid w,
  owner /home/*/.config/uSysIntChkd/jjchkconn-uSysIntChkd.steps r,

}
