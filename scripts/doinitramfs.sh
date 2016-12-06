#!/usr/bin/env bash


# ******************  Any error is a bad error. Die immediately

set -e

# ****************** Load up configurations

SCRIPT=$0
DIR=$(dirname ${SCRIPT})/../
DIR=$(readlink -f ${DIR})


if [ ! -r ${DIR}/config ]; then
	echo "Please copy config.example to config, check it, and run this again."
	exit -1
fi;

source ${DIR}/config

# ******************  Set up defaults and locations


if [ ! -r ${DIR}/defaults ]; then
	echo "defaults is not found. Something is wrong."
	exit -1
fi;

source ${DIR}/defaults


# ******************  Ensuring the build directory


if [ -d ${BUILDDIR}/initramfs ]; then
	for pat in sys proc srv/ftp; do
		if [ -d ${BUILDDIR}/initramfs/${pat} ]; then
			chmod -f u+w ${BUILDDIR}/initramfs/${pat}
		fi;
	done
	rm -rf ${BUILDDIR}/initramfs
fi;


# ******************  Creating the initramfs

(
	MODDIR=${BUILDDIR}/initramfs/lib/modules/${KERNEL_VERSION}

	cp -rf ${INITRAMFS} ${BUILDDIR}

	for pat in sys proc srv/ftp; do
		if [ -d ${BUILDDIR}/initramfs/${pat} ]; then
			chmod -f u-w ${BUILDDIR}/initramfs/${pat}
		fi;
	done

	depmod -b ${BUILDDIR}/initramfs/ ${KERNEL_VERSION}

	cd ${BUILDDIR}/initramfs/
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > ${BUILDDIR}/initramfs.igz
	cd -

	for pat in sys proc srv/ftp; do
		if [ -d ${BUILDDIR}/initramfs/${pat} ]; then
			chmod -f u+w ${BUILDDIR}/initramfs/${pat}
		fi;
	done

)


