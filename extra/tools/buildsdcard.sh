#!/usr/bin/env bash

set -e

SCRIPT=`basename $0`
IMAGE=$1
DEVICE=$2
CACHE=${3:-${HOME}/.lenovoa10/src}
OFFSET=${4:-176160768}


function usage()
{
	echo "Usage: ${SCRIPT} <image file> /dev/<disk> [cache directory] [<offset>]";
	echo
	echo "		cache directory default is: ~/.lenovoa10/src"
	echo "		offset default is: 176160768"
	echo
}

if [ "z${IMAGE}" == "z" -o "z${DEVICE}" == "z" ]; then
	usage;
	exit 1;
fi;

if [ ! -f ${IMAGE} ]; then
	echo "Image file not found"
	exit 1;
fi;

DEVICE=`basename ${DEVICE}`

REMOVABLE=`cat /sys/block/${DEVICE}/removable 2> /dev/null`
if [ "z${REMOVABLE}" != "z1" ]; then
	echo "Device is NOT removable! So I'm not going to do it. Sucks to be you."
	exit 1;
fi;

if [ ! -d "${CACHE}" ]; then
	echo "Specified cache directory non-existant."
	exit 1;
fi;


echo "Installing onto /dev/${DEVICE}"
echo "Offset: ${OFFSET}"
echo "Using image: ${IMAGE}"
echo "Writing image to device ..."

sudo dd if=${IMAGE} of=/dev/${DEVICE}

echo "Image installed"
echo "Making root filesystem"

sudo mkfs.ext4 -E offset=${OFFSET} /dev/${DEVICE}

echo "Root filesystem created"

echo "Downloading Arch installation"

(cd ${CACHE} && wget -c http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz && cd -)


TMPDIR=`mktemp -d`

echo "Mounting device on ${TMPDIR}"

sudo mount -o loop,offset=${OFFSET} /dev/${DEVICE} ${TMPDIR}

echo "Extracting filesystem"

sudo tar -C ${TMPDIR} -xzpf ${CACHE}/ArchLinuxARM-armv7-latest.tar.gz

echo "Unmounting"

sudo umount ${TMPDIR}
rmdir ${TMPDIR}

sudo parted -s /dev/${DEVICE} "mklabel msdos"
sudo parted -s /dev/${DEVICE} "mkpart primary ext4 ${OFFSET}B -1s"

sudo sync

echo "Done."


