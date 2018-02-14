#!/bin/bash

# chroot2iso.sh (Custom Debian live environment scripts) 0.0.1
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
	echo "Usage: chroot2iso.sh -d|--directory=PATH [-n|--name=NAME] [-o|--output=FILENAME]"
}

show_help() {
	usage
	echo "chroot2iso.sh --install-dependencies

Creates a bootable ISO from the Debian environment created with chrootbootstrapper.sh (or manually). The ISO file will be at PATH/NAME

Mandatory arguments to long options are mandatory for short options too.
  -d	--directory=PATH	full path to the directory where
  				the files for creating the live
				environment are stored, chroot is
				assumed to be at PATH/chroot
  -h	--help			display this help and exit
  	--install-dependencies	install the required applications via 
				apt-get and quit, only needs to be ran once
  -n	--name=NAME		name of the live OS (default: Debian Live)
  -o	--output=FILENAME	filename of the created iso
  -v	--version		show version & licence and exit

More information availabe at https://github.com/masakoodaa/custom-debian-live-environment-scripts/"
}

show_version() {
	echo "chroot2iso.sh (Custom Debian live environment scripts) 0.0.1
Copyright (C) 2018 masakoodaa
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by masakoodaa (github.com/masakoodaa).
Based on Will Haley's articles on creating custom Debian live environments."
}

# initialize all option variables
# this makes sure we aren't contamined by variables from the environment
workdir=
installdeps=false
menufile=
name="Debian Live"
outputfile="debian-live.iso"

# parse arguments
while :; do
	case $1 in
		-h|--help)
			show_help
			exit 0
			;;
		-m|--menufile)
			if [ "$2" ]
			then
				menufile="$2"
				shift
			fi
			;;
		--menufile=?*)
			menufile="${1#*=}"
			;;
		--menufile=)
			abort '"--menufile" can not be empty; see --help'
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
		--install-dependencies)
			installdeps=true
			;;
		-m|--outputfile)
			if [ "$2" ]
		       	then
				outputfile="$2"
				shift
			fi
			;;
		--outputfile=?*)
			outputfile="${1#*=}"
			;;
		--outputfile=)
			abort '"--outputfile" can be left out but can not be empty!'
			;;
		-n|--name)
			if [ "$2" ]
			then
				name="$2"
				shift
			fi
			;;
		--name=?*)
			name="${1#*=}"
			;;
		--name=)
			abort '"--name" can be left out but can not be empty!'
			;;
		-u|--usage) # undocumented super secret option ;)
			usage
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

if [ "$workdir" ] #TODO: refactor
then
	echo "Creating subdirectories..."
	mkdir -p "$workdir"/image/{live,isolinux}
else
	abort 'No directory specified!'
fi

# the easy part: actual work

# exit on fail or unset variable (just in case :D)
set -e
set -u

echo "Compressing the chroot environment into a Squash filesystem..."
#mksquashfs "$workdir"/chroot "$workdir"/image/live/filesystem.squashfs -e boot

echo "Preparing the bootloader..." #TODO: check that there's only one of each
cp "$workdir"/chroot/boot/vmlinuz-* "$workdir"/image/live/vmlinuz1
cp "$workdir"/chroot/boot/initrd.img-* "$workdir"/image/live/initrd1

echo "Creating a menu for the isolinux bootloader..."
echo "UI menu.c32

prompt 0
menu title $name

timeout 300

label $name
menu label ^$name
menu default
kernel /live/vmlinuz1
append initrd=/live/initrd1 boot=live

label hdt
menu label ^Hardware Detection Tool (HDT)
kernel hdt.c32
text help
HDT displays low-level information about the systems hardware.
endtext

label memtest86+
menu label ^Memory Failure Detection (memtest86+)
kernel /live/memtest" > "$workdir"/image/isolinux/isolinux.cfg

echo "Copying files..." #TODO: refactor into loop?
cp /usr/lib/ISOLINUX/isolinux.bin "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/menu.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/hdt.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libutil.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libmenu.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$workdir"/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libgpl.c32 "$workdir"/image/isolinux/
cp /usr/share/misc/pci.ids "$workdir"/image/isolinux/
cp /boot/memtest86+.bin "$workdir"/image/live/memtest

echo "Generating USI image..."
genisoimage -rational-rock -volid "$name" -cache-inodes -joliet -hfs -full-iso9660-filenames -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -output "$workdir"/"$outputfile" "$workdir"/image
echo "Now burn the ISO to a CD and you should be ready to boot from it and go."
