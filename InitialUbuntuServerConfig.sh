#!/bin/bash

# Made with love to be executed on an Ubuntu 16.04 LTS droplet

# Checking if the script is running as root
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

# VARIABLES SECTION
# -----------------------------------

rlog=(~/installation.log);
bckp=(bckp);
dn=/dev/null 2>&1
sshdc=(/etc/ssh/sshd_config)

# Echoes that there is no X file
nofile_echo () {
	echo -e "\e[31mThere is no file named:\e[0m \e[1m\e[31m$@\e[0m";
}

# Echoes a standard message
std_echo () {
	echo -e "\e[32mPlease check it manually.\e[0m";
	echo -e "\e[1m\e[31mThis step stops here.\e[0m";
}

blnk_echo () {
	echo "" >> $rlog;
}

# Echoes activation of a specific application option ($@)
enbl_echo () {
  echo -e "Activating \e[1m\e[34m$@\e[0m ...";
}

# Echoes that a specific application ($@) is being updated
upd_echo () {
  echo -e "Updating \e[1m\e[34m$@\e[0m application ...";
}

scn_echo () {
  echo -e "\e[1m\e[34m$@\e[0m is scanning the OS ...";
}

sctn_echo () {
	echo -e "\e[1m\e[33m$@\e[0m\n==================================================================================================" >> $rlog;
}

# Echoes that a specific application ($@) is being installed
inst_echo () {
  echo -e "Installing \e[1m\e[34m$@\e[0m" >> $rlog;
}

chg_unat10 () {
	# The following options will have unattended-upgrades check for updates every day while cleaning out the local download archive each week.
	echo "
	APT::Periodic::Update-Package-Lists "1";
	APT::Periodic::Download-Upgradeable-Packages "1";
	APT::Periodic::AutocleanInterval "7";
	APT::Periodic::Unattended-Upgrade "1";" > $unat10;
}

# Backing up a given ($@) file/directory
bckup () {
	echo -e "Backing up: \e[1m\e[34m$@\e[0m ..." >> $rlog;
	cp -r $@ $@_$(date +"%m-%d-%Y")."$bckp";
}

# Updates/upgrades the system
up () {
  sctn_echo UPDATES;
  upvar="update upgrade dist-upgrade";
  for upup in $upvar; do
    echo -e "Executing \e[1m\e[34m$upup\e[0m" >> $rlog;
    #apt-get -yqq $upup > /dev/null 2>&1 >> $rlog;
    apt-get -yqq $upup >> $rlog;
  done
  blnk_echo;
}

# Installation
inst () {
	apt-get -yqqf install $@ > /dev/null >> $rlog;
}

# ------------------------------------------
# END VARIABLES SECTION


## UFW
# Backing up the file
sctn_echo FIREWALL "(UFW)";
bckup /etc/ufw/ufw.conf;

# Limiting incomming connections to the SSH ports
ufw limit 22/tcp >> $rlog && ufw limit 7539/tcp >> $rlog;

# Opening UDP incoming connections for OpenVPN and enabling the firewall
ufw allow 1194/udp >> $rlog && ufw --force enable >> $rlog;

# Disabling IPV6 in UFW
echo "IPV6=no" >> /etc/ufw/ufw.conf && ufw reload >> $rlog;

blnk_echo;

## Updating/upgrading
up;
blnk_echo;

## Installing necessary CLI apps
sctn_echo INSTALLATION;

# The list of the apps
appcli="arp-scan clamav clamav-daemon clamav-freshclam curl git glances htop iptraf mc ntp ntpdate rcconf rig screen shellcheck sysbench sysv-rc-conf tmux unattended-upgrades whois"

# The main multi-loop for installing apps/libs
for a in $appcli; do
	inst_echo $a;
	inst $a;
done

blnk_echo;

## Unattended-Upgrades configuration section
sctn_echo AUTOUPDATES "(Unattended-Upgrades)";

unat20=(/etc/apt/apt.conf.d/20auto-upgrades);
unat50=(/etc/apt/apt.conf.d/50unattended-upgrades);
unat10=(/etc/apt/apt.conf.d/10periodic);

# Cheking the existence of the $unat20, $unat50, $unat10 configuration files
if [[ -f $unat20 ]] && [[ -f $unat50 ]] && [[ -f $unat10 ]]; then

	for i in $unat20 $unat50 $unat10; do
		bckup $i && mv $i*."$bckp" ~;
	done


	# Inserting the right values into it
	echo "
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "2";" > $unat20;


	# Checking if line for security updates is uncommented, by default it is
	if [[ $(cat $unat50 | grep -wx '[[:space:]]"${distro_id}:${distro_codename}-security";') ]]; then

		chg_unat10;
	else
		echo "
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
	"${distro_id}:${distro_codename}";
	"${distro_id}:${distro_codename}-security";
	// Extended Security Maintenance; doesn't necessarily exist for
	// every release and this system may not have it installed, but if
	// available, the policy for updates is such that unattended-upgrades
	// should also install from here by default.
	"${distro_id}ESM:${distro_codename}";
	//	"${distro_id}:${distro_codename}-updates";
	//	"${distro_id}:${distro_codename}-proposed";
	//	"${distro_id}:${distro_codename}-backports";
};

// List of packages to not update (regexp are supported)
Unattended-Upgrade::Package-Blacklist {
	//	"vim";
	//	"libc6";
	//	"libc6-dev";
	//	"libc6-i686";
};

// This option allows you to control if on a unclean dpkg exit
// unattended-upgrades will automatically run
//   dpkg --force-confold --configure -a
// The default is true, to ensure updates keep getting installed
//Unattended-Upgrade::AutoFixInterruptedDpkg "false";

// Split the upgrade into the smallest possible chunks so that
// they can be interrupted with SIGUSR1. This makes the upgrade
// a bit slower but it has the benefit that shutdown while a upgrade
// is running is possible (with a small delay)
//Unattended-Upgrade::MinimalSteps "true";

// Install all unattended-upgrades when the machine is shuting down
// instead of doing it in the background while the machine is running
// This will (obviously) make shutdown slower
//Unattended-Upgrade::InstallOnShutdown "true";

// Send email to this address for problems or packages upgrades
// If empty or unset then no email is sent, make sure that you
// have a working mail setup on your system. A package that provides
// 'mailx' must be installed. E.g. "user@example.com"
//Unattended-Upgrade::Mail "root";

// Set this value to "true" to get emails only on errors. Default
// is to always send a mail if Unattended-Upgrade::Mail is set
//Unattended-Upgrade::MailOnlyOnError "true";

// Do automatic removal of new unused dependencies after the upgrade
// (equivalent to apt-get autoremove)
//Unattended-Upgrade::Remove-Unused-Dependencies "false";

// Automatically reboot *WITHOUT CONFIRMATION*
//  if the file /var/run/reboot-required is found after the upgrade
//Unattended-Upgrade::Automatic-Reboot "false";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//  Default: "now"
//Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Use apt bandwidth limit feature, this example limits the download
// speed to 70kb/sec
//Acquire::http::Dl-Limit "70";" > $unat50;

		chg_unat10;
	fi

	# The results of unattended-upgrades will be logged to /var/log/unattended-upgrades.
	# For more tweaks nano /etc/apt/apt.conf.d/50unattended-upgrades

	blnk_echo >> $rlog;

else
	nofile_echo $unat20 or $unat50 or $unat10;
	std_echo;
fi

blnk_echo;

# END: Unattended-Upgrades configuration section


# ClamAV section: configuration and the first scan

clmcnf=(/etc/clamav/freshclam.conf);
rprtfldr=(~/ClamAV-Reports);

sctn_echo ANTIVIRUS "(Clam-AV)" >> $rlog;
bckup $clmcnf;
mkdir -p $rprtfldr;


# Enabling "SafeBrowsing true" mode
enbl_echo SafeBrowsing >> $rlog;
echo "SafeBrowsing true" >> $clmcnf;

# Restarting CLAMAV Daemons
/etc/init.d/clamav-daemon restart && /etc/init.d/clamav-freshclam restart
# clamdscan -V s

# Scanning the whole system and palcing all the infected files list on a particular file
echo "ClamAV is scanning the OS ...";
scn_echo ClamAv >> $rlog;
# This one throws any kind of warnings and errors: clamscan -r / | grep FOUND >> $rprtfldr/clamscan_first_scan.txt >> $rlog;
clamscan --recursive --no-summary --infected / 2>/dev/null | grep FOUND >> $rprtfldr/clamscan_first_scan.txt;
# Crontab: The daily scan

# This way, Anacron ensures that if the computer is off during the time interval when it is supposed to be scanned by the daemon, it will be scanned next time it is turned on, no matter today or another day.
echo -e "Creating a \e[1m\e[34mcronjob\e[0m for the ClamAV ..." >> $rlog;
echo -e '#!/bin/bash\n\n/usr/bin/freshclam --quiet;\n/usr/bin/clamscan --recursive --exclude-dir=/media/ --no-summary --infected / 2>/dev/null >> '$rprtfldr'/clamscan_daily_$(date +"%m-%d-%Y").txt;' >> /etc/cron.daily/clamscan.sh && chmod 755 /etc/cron.daily/clamscan.sh;

blnk_echo;

# # END: ClamAV section: configuration and the first scan


# Cloning OpenVPN installation script
sctn_echo OPEVNPN SECTION
cd ~ && git clone -b DEV https://github.com/crtcji/OpenVPN-install && cd OpenVPN-install && chmod 755 openvpn-install.sh;
#git clone https://github.com/Angristan/OpenVPN-install

## MANUAL WORK
# ========================================================================================================

## Run openvpn.sh
sctn_echo RUNNING OPENVPN INSTALL .... ;
./openvpn-install.sh

echo "duplicate-cn" >> /etc/openvpn/server.conf
service openvpn@server restart

sctn_echo SSHD CONFIG;

bckup sshdc;

#Port 7539
sed -i -re 's/^(Port)([[:space:]]+)22/\1\27539/' $sshdc;

## Authentication: 1440m - 24h
sed -i -re 's/^(LoginGraceTime)([[:space:]]+)120/\1\21440m/' $sshdc;

#Banner /etc/issue.net
sed -i -re 's/^(\#)(Banner)([[:space:]]+)(.*)/\2\3\4/' $sshdc;
service ssh restart

sctn_echo UFW UPDATE;
yes | ufw delete 1 && ufw reload

echo "Done" >> $rlog;
