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
	chmod -f u+w ${BUILDDIR}/initramfs/{sys,proc,srv/ftp}
	rm -rf ${BUILDDIR}/initramfs
fi;


# ******************  Creating the initramfs

(
	MODDIR=${BUILDDIR}/initramfs/lib/modules/${LVERSION}
	LENOVODIR=${MODDIR}/lenovo

	cp -rf ${INITRAMFS} ${BUILDDIR}
	mkdir -p ${LENOVODIR}
	cp -rf ${DIR}/originals/modules/* ${LENOVODIR}/

	chmod -f u-w ${BUILDDIR}/initramfs/{sys,proc,srv/ftp}

	depmod -b ${BUILDDIR}/initramfs/ ${LVERSION}

	cd ${BUILDDIR}/initramfs/
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > ${BUILDDIR}/initramfs.igz
	cd -

	chmod -f u+w ${BUILDDIR}/initramfs/{sys,proc,srv/ftp}
)


