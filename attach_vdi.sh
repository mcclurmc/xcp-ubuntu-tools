#!/bin/bash

set -e
set -x

function usage () {
	echo "Usage: $(basename $0) <server> <user> <vm_uuid> <vdi_uuid>"
	exit 1
}

if [ "$#" -ne 4 ]; then
	usage
fi

# Parameters. In order because I'm lazy.
SERVER=$1
USER=$2
VM=$3
VDI=$4

read -s -p "Password: " PASSWD ; echo

xe="xe -u ${USER} -pw ${PASSWD} -s ${SERVER}"

$xe vbd-create \
    vdi-uuid=${VDI} \
    vm-uuid=${VM} \
    device=1 \
    unpluggable=true \
    type=Disk \
    mode=ro \
    bootable=false
