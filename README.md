jjchkconn

jjchkconn v1.2.2-RC13: Modify various installation, apparmor, SystemD, and file permissions to correct the inability to send Slack alerts.  It is working now.
Monitor Internet Connectivity, with alerts using a Slack channel, for Systemd distros.

About

jjchkconn is a set of customizable systemd units, ini files, and bash scripts that will monitor Internet connectivity and, upon failure, send alerts via a Slack channel after connectivity resumes.

Disclaimer

jjchkconn was converted from a number of standalone scripts and systemd units into one integrated package.  It is also meant to take email messages to the alerts@localhost and generate Slack alerts out of those.

Build:

cd source_directory; dpkg-deb --build . jjchkconn.deb

Installation:

All components have been packaged in a .deb(ian) package and are ready for installation on Ubuntu (22.04).  Debian compatibility has yet to be tested, but it relies on packages commonly found on Ubuntu and Debian repositories.

dpkg -i jjchkconn.deb

Permissions and ownership are ready for action.  The Slack webhooks ini file must be changed manually.  Insert the Slack incoming webhook URL as stated below.

Configurations

jjchkconn-slack-alerts.ini file requires manual configuration.  "https://hooks.slack.com/services/" is a placeholder.  Fetch the URL from your Slack channel's API site.

	WebHook=https://hooks.slack.com/services/

jjchkconn-uSysIntChkd.ini file requires manual configuration.

jjchkconn-uSysIntChkd.steps file requires manual configuration.  Running speedtest-cli can be used to customize the various URLs that can be used with wget to test connectivity.  With more entries the frequency of wget or ping will decrease and the owners of the sites used may ignore.  With less entries the frequency will be higher, you'll be more noticeable and the risk of blocking you increases.


jjchkconn-uSysIntChkd.next file does not require manual configuration anymore, although always starting with the number 1 is very safe.

Thank for your support!   

If you so desire your donations may be sent to: https://paypal.me/jj10netllc 
