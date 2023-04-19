#!/bin/bash

# This script generates a backup of all active libvirtd domains on the host where it is executed. 
# It was created as a lightweight backup solution for a pure libvirtd virtual machine host. 
# You are free to use or modify this script as you wish. If you encounter any bugs or issues, 
# or have suggestions for improvements, please let me know. If the debug flag is set to 1, 
# the script will produce more detailed output for debugging purposes.
VERBOSE=1

# Set the script language to English
LANG=en_US.UTF-8

# Define the script name for use in the journal
SCRIPTNAME=kvm-backup-test

# List the domains
DOMAINS="$(virsh list| tail -n +3 | awk '{print $2}')"

# Loop over the domains and start the backup cycle.
for DOMAIN in $DOMAINS; do

	# Check if the ignore backup config file (/etc/kvm-backup.ignore) exists
	# and parse it if required.
	if [[ -f /etc/kvm-backup.ignore ]]; then
		if grep -Fxq "$DOMAIN" /etc/kvm-backup.ignore; then
			systemd-cat -t $SCRIPTNAME echo "Ignoring domain '$DOMAIN' per config"
			continue
		fi
	fi

	systemd-cat -t $SCRIPTNAME echo "Starting backup for domain '$DOMAIN'"

	# Generate the backup folder URI
	# Lifed from Aaron Studer's revision of my original script, see
	# https://gist.github.com/aaronstuder/f481f4b9ff270f9ddcd098f283dc71cd#file-kvm-backup-sh-L24
	# for source
	BACKUPFOLDER="/mnt/backups/$DOMAIN/$(date +%Y)/$(date +%m)/$(date +%d)/"

	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Backup folder URI is '$BACKUPFOLDER'"
	fi

	if [[ ! -d $BACKUPFOLDER ]]; then
		mkdir -p $BACKUPFOLDER
	fi

	# Get VM disk info
	DISKINFO=$(virsh domblklist $DOMAIN --details | grep disk | awk '{print $3,$4}')

	# Get the disk type (sda, vda, etc)
	DISKTYPE=$(echo $DISKINFO | awk '{print $1}')

	# Get the disk path
	DISKPATH=$(echo $DISKINFO | awk '{print $2}')

	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Disk info is '$DISKINFO', disk type is '$DISKTYPE', disk path is '$DISKPATH'"
	fi

	# Do the snapshot
	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME virsh snapshot-create-as --domain $DOMAIN --name "snapshot" --no-metadata --atomic --disk-only --diskspec $DISKTYPE,snapshot=external
	else
		virsh snapshot-create-as --domain $DOMAIN --name "snapshot" --no-metadata --atomic --disk-only --diskspec $DISKTYPE,snapshot=external > /dev/null
	fi

	if [[ $? -ne 0 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Failed to create snapshot for domain '$DOMAIN'"
	fi

	# Copy the disk image
	DISKPATHBASENAME=$(basename $DISKPATH)
	cp $DISKPATH $BACKUPFOLDER/$DISKPATHBASENAME

	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Done copying the disk for domain '$DOMAIN'"
	fi

	# Get the backup disk (sda, vda, etc) path now so we can
	# remove it later
	BACKUPDISKPATH=$(virsh domblklist $DOMAIN --details | grep disk | awk '{print $4}')

	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Backup disk path is '$BACKUPDISKPATH'"
	fi

	# merge the changes back
	if [[ $VERBOSE -eq 1 ]]; then
		systemd-cat -t $SCRIPTNAME virsh blockcommit $DOMAIN $DISKTYPE --active --pivot
	else
		virsh blockcommit $DOMAIN $DISKTYPE --active --pivot > /dev/null
	fi

	if [[ $? -ne 0 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Could not merge changed for disk of type '$DISKTYPE' on domain '$DOMAIN'. VM *may* be in an invalid state."
	else
		rm -f $BACKUPDISKPATH

		if [[ $VERBOSE -eq 1 ]]; then
			systemd-cat -t $SCRIPTNAME  echo "Removed backup disk for domain '$DOMAIN'"
		fi
	fi

	# Dump the VM xml
	virsh dumpxml $DOMAIN > $BACKUPFOLDER/$DOMAIN.xml

	if [[ $? -ne -0 ]]; then
		systemd-cat -t $SCRIPTNAME echo "Could not dump XML for domain '$DOMAIN'"
	fi

	systemd-cat -t $SCRIPTNAME echo "Finished backup of domain '$DOMAIN'"

done

exit 0