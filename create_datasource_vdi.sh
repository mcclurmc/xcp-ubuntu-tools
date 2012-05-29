#!/bin/bash

# Create a datasource vdi from the contents of a directory. Requires xe to be
# installed (xcp-xe package on Debian/Ubuntu).

set -e
set -x

function usage () {
	echo "Usage: $(basename $0) <server> <user> <dir> <sr_uuid>"
	exit 1
}

if [ "$#" -ne 4 ]; then
	usage
fi

# Parameters. In order because I'm lazy.
SERVER=$1
USER=$2
DS_DIR=$3
SR_UUID=$4

read -s -p "Password: " PASSWD ; echo

xe="xe -u ${USER} -pw ${PASSWD} -s ${SERVER}"

# Create image from contents of datasource dir (from
# cloud-init/doc/nocloud/README). We assume we won't need more than 2M.
IMG_FILE=$(mktemp --tmpdir seed-XXX.img)
truncate --size 2M ${IMG_FILE}
mkfs.vfat -n cidata ${IMG_FILE}
mcopy -oi ${IMG_FILE} ${DS_DIR}/* ::

# Create VDI for datasource image
VDI=$($xe vdi-create \
	name-label=ds-vdi \
	sharable=true \
	sr-uuid=${SR_UUID} \
	virtual-size=2MiB \
	type=user)

# Import raw VDI
curl -v -u root:${PASSWD} -T ${IMG_FILE} \
	"http://${SERVER}/import_raw_vdi?vdi=${VDI}"

rm ${IMG_FILE}

# Return VDI uuid
echo ${VDI}
