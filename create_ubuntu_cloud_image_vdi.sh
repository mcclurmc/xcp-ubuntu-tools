#!/bin/bash

set -e
set -x

# Script to create a bootable XCP VDI from an ubuntu cloud image root tarball.
# This should be run in your dom0.

if [ -z $1 ]; then
	echo "Usage: $(basename $0) <ubuntu-cloud-image-root.tar.gz>"
	exit 1
fi

# Source the inventory, whether we're on XenServer/XCP or using xcp-xapi on a
# Linux distro.
[ -f /etc/xcp/inventory ] && . /etc/xcp/inventory 
[ -f /etc/xensource-inventory ] && . /etc/xensource/inventory

VDI_SIZE='8GiB'
UCI_TAR=$1
DEFAULT_SR=$(xe pool-param-get uuid=$(xe pool-list --minimal) param-name=default-SR)
VBD_LAST_DEV=$(xe vbd-list \
                    vm-uuid=$CONTROL_DOMAIN_UUID \
                    params=userdevice --minimal \
                | tr ',' '\n' | tail -1)
VBD_DEV=$((1 + ${VBD_LAST_DEV:-'-1'}))
MNT_DIR=/mnt

# create the VDI
VDI=$(xe vdi-create \
	name-label=ubuntu-cloud-image-vdi \
	shareable=true \
	type=user \
	virtual-size=${VDI_SIZE} \
	sr-uuid=${DEFAULT_SR})

# create vbd, plug it and create a filesystem
VBD=$(xe vbd-create \
	vm-uuid=${CONTROL_DOMAIN_UUID} \
	vdi-uuid=${VDI} \
	device=${VBD_DEV} \
	type=Disk \
	mode=rw \
	unpluggable=true)

xe vbd-plug uuid=${VBD}
VDI_DEV="/dev/sm/backend/${DEFAULT_SR}/${VDI}"
mkfs.ext4 -L cloudimg-rootfs ${VDI_DEV}

# Mount VDI and untar cloud image files 
mount ${VDI_DEV} ${MNT_DIR}

if [ $(echo ${UCI_TAR} | cut -b 1 -) != '/' ]; then
	UCI_TAR=$(pwd)/${UCI_TAR}
fi

cd ${MNT_DIR}
tar xf ${UCI_TAR}
cd -

# Unmount VDI and unplug/destroy VBD
umount ${MNT_DIR}
xe vbd-unplug uuid=${VBD}
xe vbd-destroy uuid=${VBD}

# echo VDI uuid
echo ${VDI}

