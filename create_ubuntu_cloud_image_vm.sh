#!/bin/bash

set -e
set -x

# Create a VM using a particular VDI as root disk.

if [ -z $1 ]; then
	echo "Usage: $(basename $0) <root vdi uuid>"
	exit 1
fi

TEMPLATE="Ubuntu Precise Pangolin 12.04 (64-bit) (experimental)"
VM_NAME="ubuntu-precise-cloud"
VDI=$1

# Create VM
echo \"${TEMPLATE}\"

VM=$(xe vm-install \
	template="${TEMPLATE}" \
	new-name-label=${VM_NAME})

# Remove VM's VDI and add our own
OLD_VBD=$(xe vbd-list vm-uuid=${VM} --minimal)
OLD_VDI=$(xe vdi-list vbd-uuids:contains=${OLD_VBD} --minimal)

xe vdi-destroy uuid=${OLD_VDI}

xe vbd-create \
	vm-uuid=${VM} \
	vdi-uuid=${VDI} \
	device=0 \
	type=Disk \
	bootable=true \
	mode=rw \
	unpluggable=false

# Add VIFs for xenbr0 and xenapi networks
XENBR0=$(xe network-list bridge=xenbr0 --minimal)
XENAPI=$(xe network-list bridge=xenapi --minimal)

xe vif-create vm-uuid=${VM} device=0 network-uuid=${XENBR0}
xe vif-create vm-uuid=${VM} device=1 network-uuid=${XENAPI}

# Set the bootloader to pygrub
xe vm-param-set uuid=${VM} PV-bootloader=pygrub

# Return the VM's uuid
echo $VM
