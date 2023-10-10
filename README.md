jjchkconn

jjchkconn v1.3.1 : This version includes mods for additional step-type indicators in the steps_file.  These include:
	New Functionality:
	Type2 operations, used to target local gateways, Intranet sites of
	interest, and other sites of interest.
	- dgn: Default gateway, network.  Will accept one or more ot these
	  to monitor single-WAN or multi-WAN setups.
	- dgl: Default gateway, local.  Local system gateway.  Eliminates
	  the need for a 2nd argument on the line since it will derive
	  the default gateway using `ip route|grep default`.
	- tr: Transit node.  This will handle relevant node(s) to watch,
	  particularly on the path between the local host (dgl) and the default
	  gateway (dgn).  Can also be used for external relevant sites.

	dgn,dgl, and tr are to be used to assesss latency and packet loss, not 
	full out-of-service conditions.
	
	Other additions:
	- Modify fReadStepsAndCheck function to use uConnStat in the if 
	  condition, with new indicator values.
	- Create new function to evaluate packet loss and latency for the
	  three new step-type indicators.   Use ping with the same packet
	  size, but a new minimum ping count of 3, in order to average the
	  round trip statistics.
	- Multiple code optimizations.

	Bug fixes:
	- sendmsg2slack.sh is incorrectly being called using bash, when it is
	  a sh script.  Either remove "bash" or change it to "sh".

Starting with v1.3.1 it will not only monitor Internet connectivity.  It will Monitor various Network Connectivity issues, with alerts using a Slack channel, for Systemd distros.

About

jjchkconn is a set of customizable systemd units, ini files, and bash scripts that will monitor Internet connectivity and, upon failure, send alerts via a Slack channel after connectivity resumes.

Disclaimer

jjchkconn was converted from a number of standalone scripts and systemd units into one integrated package.  It is also meant to take email messages to the alerts@localhost and generate Slack alerts out of those.

Build:

cd source_directory; dpkg-deb --build . jjchkconn.deb

Installation:

All components have been packaged in a .deb(ian) package and are ready for installation on Ubuntu (22.04).  Debian compatibility has yet to be tested, but it relies on packages commonly found on Ubuntu and Debian repositories.

dpkg -i jjchkconn.deb

Permissions and ownership are ready for action.  The Slack sendmsg ini file must be changed manually.  Insert the Slack ChannelID and BotToken information as stated below.

Configurations

jjchkconn-slack-alerts.ini file requires manual configuration.  Fetch the data from your Slack channel's API site.

	ChannelID=<slack-channel-id>
	BotToken=<slack-bot-token>

jjchkconn-uSysIntChkd.ini file requires manual configuration.

jjchkconn-uSysIntChkd.steps file requires manual configuration.  Running speedtest-cli can be used to customize the various URLs that can be used with wget to test connectivity.  With more entries the frequency of wget or ping will decrease and the owners of the sites used may ignore.  With less entries the frequency will be higher, you'll be more noticeable and the risk of blocking you increases.


jjchkconn-uSysIntChkd.next file does not require manual configuration anymore, although always starting with the number 1 is very safe.

Thank for your support!   

If you so desire your donations may be sent to: https://paypal.me/jj10netllc 
