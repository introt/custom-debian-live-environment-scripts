#!/bin/bash

# chrootbootstrapper.sh (Custom Debian live environment scripts) 1.0.0
#
# Copyright (C) 2018 masakoodaa
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
#
# Written by masakoodaa (github.com/masakoodaa).
# Based on Will Haley's articles on creating custom Debian live environments.
#
# Upstream: https://github.com/masakoodaa/custom-debian-live-environment-scripts/

abort() {
	printf '%s\n' "$1" >&2
	exit 1
}

usage() {
	echo "Usage: chrootbootstrapper.sh [-a|--arch=ARCH] -d|--directory=PATH [--hybrid] [-m|--mirror=MIRROR] [-n|--hostname=HOSTNAME] [-s|--suite=SUITE] [--variant=VARIANT]
	chrootbootstrapper.sh --install-dependencies [--hybrid]"
}

show_help() {
	usage
	echo "
Creates and sets up a base Debian environment (for the purpose of creating a live environment) in the given directory.

Mandatory arguments to long options are mandatory for short options too.
  -a	--arch=ARCH		OS architecture (default: amd64)
  -d	--directory=PATH	full path to the directory where
  				the files for creating the live
				environment will be stored,
  				must be in a partition that is
				NOT mounted with noexec or nodev
  -h	--help			display this help and exit
  	--hybrid		hybrid boot partition allows booting on
				both EFI and BIOS systems (default: BIOS only)
				does NOT work (yet) with chroot2iso.sh
				and DOES NOT WORK WITH Debian 8 (Jessie)
  	--install-dependencies	install the required applications via 
				apt-get and quit, only needs to be ran once
  -m	--mirror=MIRROR		Debian mirror to download files from
  				default: http://ftp.us.debian.org/debian/
  -n	--hostname=HOSTNAME	chroot hostname (default: debian-live)
  -s	--suite			Debian release codename (default: stretch)
  				or symbolic name; see DEBOOTSTRAP(8)
  	--variant		default: minbase; see DEBOOTSTRAP(8)
  -v	--version		show version & licence and exit

\"--install-dependencies\" can be used together with \"--hybrid\" to install the extra dependencies needed for building chroots with hybrid boot partitions.
  
You will need to choose and install a kernel (and set a root password) in the chroot before running chroot2iso.sh (which does NOT support \"--hybrid\" yet!)

More information availabe at https://github.com/masakoodaa/custom-debian-live-environment-scripts/"
}

show_version() {
	echo "chrootbootstrapper.sh (Custom Debian live environment scripts) 1.0.0
Copyright (C) 2018 masakoodaa
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by masakoodaa (github.com/masakoodaa).
Based on Will Haley's articles on creating custom Debian live environments."
}

# initialize all option variables
# this makes sure we aren't contamined by variables from the environment
arch="amd64"
hostname="debian-live"
hybrid=false
installdeps=false
mirror="http://ftp.us.debian.org/debian/"
suite="stretch"
variant="minbase"
workdir=

# parse arguments
while :; do
	case $1 in
		-h|--help)
			show_help
			exit 0
			;;
		-a|--arch)
			if [ "$2" ]
			then
				arch="$2"
				shift
			fi
			;;
		--arch=?*)
			arch="${1#*=}"
			;;
		--arch=)
			abort '"--arch" can be left out but can not be empty!'
			;;
		-d|--directory)
			if [ "$2" ]
			then
				workdir="$2"
				shift
			fi
			;;
		--directory=?*)
			workdir="${1#*=}"
			;;
		--directory=)
			abort '"--directory" must specify a path; see --help'
			;;
		--hybrid)
			hybrid=true
			echo "WARNING: chroot2iso.sh doesn't support \"--hybrid\" (yet), so you can't build an iso with it."
			;;
		--install-dependencies)
			installdeps=true
			;;
		-m|--mirror)
			if [ "$2" ]
		       	then
				mirror="$2"
				shift
			fi
			;;
		--mirror=?*)
			mirror="${1#*=}"
			;;
		--mirror=)
			abort '"--mirror" can be left out but can not be empty!'
			;;
		-n|--hostname)
			if [ "$2" ]
			then
				hostname="$2"
				shift
			fi
			;;
		--hostname=?*)
			hostname="${1#*=}"
			;;
		--hostname=)
			abort '"--hostname" can be left out but can not be empty!'
			;;
		-u|--usage) # undocumented super secret option ;)
			usage
			;;
		-s|--suite)
			if [ "$2" ]
			then
				suite="$2"
				shift
			fi
			;;
		--suite=?*)
			suite="${1#*=}"
			;;
		--suite=)
			abort '"--suite" can be left out but can not be empty!'
			;;
		--variant)
			if [ "$2" ]
			then
				variant="$2"
				shift
			fi
			;;
		--variant=?*)
			variant="${1#*=}"
			;;
		--variant=)
			abort '"--variant" can be left out but can not be empty!'
			;;
		-v|--version)
			show_version
			exit 0
			;;
		--)
			shift
			break
			;;
		-?*)
			abort 'Unknown option. See \"--help\" for help or \"--usage\" for usage.'
			;;
		*)
			break
	esac
	
	shift
done

# make sure we are root & good to go
if [ "$EUID" -ne 0 ]
then
	echo "Missing root privileges. Aborting."
	exit 1
fi

dependencies="chroot debootstrap syslinux isolinux squashfs-tools genisoimage memtest86+ rsync"
if [ "$hybrid" = true ]
then
	dependencies="$dependencies gdisk grub2-common grub-efi-amd64"
fi

# install dependencies
if [ "$installdeps" = true ]
then
	echo "Installing dependencies..."
	apt-get update
	apt-get install -y $dependencies \
		&& echo "Dependencies installed successfully" \
		|| abort 'Installation failed!'
fi

# check if the dependencies are installed
for i in $dependencies
do
	case $i in
		isolinux)
			if [ ! -f "/usr/lib/ISOLINUX/isolinux.bin" ]
			then
				abort "$i is required but is not installed; see \"--help\""
			fi
			;;
		squashfs-tools)
			hash mksquashfs 2>&1 || abort "$i is required but is not installed; see \"--help\""
			;;
		memtest86+)
			if [ ! -f "/boot/memtest86+.bin" ]
			then
				abort "$i is required but is not installed; see \"--help\""
			fi
			;;

		*)
			hash $i 2>&1 || abort "$i is required but is not installed; see \"--help\""
			;;

	esac
done

# check if $workdir is given and whether the directory exists or needs to be created

# remove trailing slash
workdir=${workdir%%+(/)}

if [ "$workdir" ]
then
	if [ ! -d "$workdir" ]
	then
		echo "Creating directory $workdir and subdirectories"
		mkdir -p "$workdir"/{chroot,image/{live,isolinux}}
	fi
else
	abort 'No directory specified!'
fi

# exit on fail or unset variable (just in case :D)
set -e
set -u

# the easy part: actual work

echo "Bootstrapping..."
debootstrap --arch="$arch" --variant="$variant" "$suite" "$workdir"/chroot "$mirror"

echo "Setting hostname..."
echo "$hostname" > "$workdir/chroot/etc/hostname"

echo "Installing live-boot and systemd-sys in chroot..." #TODO: provide other inits
chroot "$workdir"/chroot /bin/bash -c "apt-get update && apt-get install -y --no-install-recommends live-boot systemd-sysv"

echo "All done! Remember to install a kernel (and set root password) before running chroot2iso.sh"
exit 0
