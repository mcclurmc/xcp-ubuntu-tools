#!/bin/bash

set -e
set -x

function usage () {
	echo "Usage: $(basename $0) <server> <user> <cloud_image.img>"
	exit 1
}

if [ "$#" -ne 3 ]; then
	usage
fi

# Parameters. In order because I'm lazy.
SERVER=$1
USER=$2
CI_IMG=$3

read -s -p "Password: " PASSWD ; echo

xe="xe -u ${USER} -pw ${PASSWD} -s ${SERVER}"

# Globals
TEMPLATE="Ubuntu Precise Pangolin 12.04 (64-bit) (experimental)"
VM_NAME="ubuntu-precise-cloud"

# Create VM
VM=$($xe vm-install \
	template="${TEMPLATE}" \
	new-name-label=${VM_NAME})

VDI=$($xe vbd-list \
	vm-uuid=${VM} \
	params=vdi-uuid \
	--minimal)

# import raw vdi
curl -k -u ${USER}:${PASSWD} -T ${CI_IMG} \
	"http://${SERVER}/import_raw_vdi?vdi=${VDI}"

# Add VIFs for xenbr0 and xenapi networks
XENBR0=$($xe network-list bridge=xenbr0 --minimal)
XENAPI=$($xe network-list bridge=xenapi --minimal)

$xe vif-create vm-uuid=${VM} device=0 network-uuid=${XENBR0}
$xe vif-create vm-uuid=${VM} device=1 network-uuid=${XENAPI}

# Set the bootloader to pygrub
$xe vm-param-set uuid=${VM} PV-bootloader=pygrub

# Return the VM's uuid
echo $VM
