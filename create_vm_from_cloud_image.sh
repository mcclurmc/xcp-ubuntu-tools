#!/bin/bash

set -e
set -x

if [ -z $1 ]; then
	echo "Usage: $(basename $0) <cloud_image.img> <datasource.img>"
	exit 1
fi

if [ -z $2 ]; then
	echo "Usage: $(basename $0) <cloud_image.img> <datasource.img>"
	exit 1
fi

# Source the inventory, whether we're on XenServer/XCP or using xcp-xapi on a
# Linux distro.
[ -f /etc/xcp/inventory ] && . /etc/xcp/inventory 
[ -f /etc/xensource-inventory ] && . /etc/xensource/inventory

# Globals
TEMPLATE="Ubuntu Precise Pangolin 12.04 (64-bit) (experimental)"
VM_NAME="ubuntu-precise-cloud"
CI_IMG=$1
DS_IMG=$2

# Find next dom0 user device for VBDs
VBD_LAST_DEV=$(xe vbd-list \
                    vm-uuid=$CONTROL_DOMAIN_UUID \
                    params=userdevice --minimal \
                | tr ',' '\n' | sort | tail -1)
VBD_DEV=$((1 + ${VBD_LAST_DEV:-'-1'}))

# Get default SR
DEFAULT_SR=$(xe pool-param-get \
	uuid=$(xe pool-list --minimal) \
	param-name=default-SR)

# Create VM
VM=$(xe vm-install \
	template="${TEMPLATE}" \
	new-name-label=${VM_NAME})

# Create VBD for dom0 and new VDI
VDI=$(xe vbd-list \
	vm-uuid=${VM} \
	userdevice=0 \
	params=vdi-uuid \
	--minimal)

VBD=$(xe vbd-create \
	vm-uuid=${CONTROL_DOMAIN_UUID} \
	vdi-uuid=${VDI} \
	device=${VBD_DEV} \
	type=Disk \
	bootable=true \
	mode=rw \
	unpluggable=true)

xe vdi-param-set uuid=${VDI} name-label="${VM_NAME}-vdi-0"

# Plug VBD and dd image to it
xe vbd-plug uuid=${VBD}
VDI_DEV="/dev/sm/backend/${DEFAULT_SR}/${VDI}" 
dd if=${CI_IMG} of=${VDI_DEV} bs=4MiB
xe vbd-unplug uuid=${VBD}
xe vbd-destroy uuid=${VBD}

# Create new VDI for datasource, dd image and add to VM
DS_SIZE=$(ls -s ${DS_IMG} | cut -f1 -d' ')
xe vm-disk-add uuid=${VM} disk-size=${DS_SIZE} device=1
DS_VDI=$(xe vbd-list vm-uuid=${VM} userdevice=1 params=vdi-uuid --minimal)
xe vdi-param-set uuid=${DS_VDI} name-label="${VM_NAME}-ds-vdi"

VBD=$(xe vbd-create \
	vm-uuid=${CONTROL_DOMAIN_UUID} \
	vdi-uuid=${DS_VDI} \
	device=${VBD_DEV} \
	type=Disk \
	bootable=true \
	mode=rw \
	unpluggable=true)

xe vbd-plug uuid=${VBD}
VDI_DEV="/dev/sm/backend/${DEFAULT_SR}/${DS_VDI}" 
dd if=${DS_IMG} of=${VDI_DEV} bs=1k
xe vbd-unplug uuid=${VBD}
xe vbd-destroy uuid=${VBD}

# Add VIFs for xenbr0 and xenapi networks
XENBR0=$(xe network-list bridge=xenbr0 --minimal)
XENAPI=$(xe network-list bridge=xenapi --minimal)

xe vif-create vm-uuid=${VM} device=0 network-uuid=${XENBR0}
xe vif-create vm-uuid=${VM} device=1 network-uuid=${XENAPI}

# Set the bootloader to pygrub
xe vm-param-set uuid=${VM} PV-bootloader=pygrub

# Return the VM's uuid
echo $VM
