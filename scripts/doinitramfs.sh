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

if [ ! -d ${BUILDDIR} ]; then
	mkdir -p ${BUILDDIR};
fi;


# ******************  Creating the initramfs

(
	cd ${INITRAMFS}
	find . | cpio -H newc -o > ${BUILDDIR}/initramfs.cpio
	cat ${BUILDDIR}/initramfs.cpio | gzip -9 > ${BUILDDIR}/initramfs.igz
	cd -
)


