#!/usr/bin/env bash

set -e


SCRIPT=$0
DIR=$(dirname ${SCRIPT})
DIR=$(readlink -f ${DIR})

if [ ! -r ${DIR}/config ]; then
	echo "Please copy config.example to config, check it, and run this again."
	exit -1
fi;

source ${DIR}/config

BUILDDIR=${DIR}/${BUILD}
OFILE=${BUILDDIR}/sdboot_rk3188.img

dd if=/dev/zero of=${OFILE} conv=sync,fsync \
	bs=512 count=8192

dd if=${BUILDDIR}/sd_header.1.rc4 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=64
dd if=${BUILDDIR}/sd_header.2.rc4 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=65

dd if=${BUILDDIR}/FlashData.bin.rc4 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=68
dd if=${BUILDDIR}/FlashBoot.bin.rc4 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=92

# ----------------

dd if=${BUILDDIR}/unknown.1 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=8064

dd if=${BUILDDIR}/unknown.2 of=${OFILE} conv=notrunc,sync,fsync \
	bs=512 seek=8065


# ----------------

dd if=${BUILDDIR}/parameters.img of=${OFILE} conv=notrunc,sync,fsync \
	seek=$((0x2000))

dd if=${BUILDDIR}/kernel.img of=${OFILE} conv=notrunc,sync,fsync \
	seek=$((0x2000 + 0x4000))

dd if=${BUILDDIR}/boot.img of=${OFILE} conv=notrunc,sync,fsync \
	seek=$((0x2000 + 0x8000))




