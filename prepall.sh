#!/usr/bin/env bash


# ******************  Any error is a bad error. Die immediately

set -e


# ****************** Load up configurations

SCRIPT=$0
DIR=$(dirname ${SCRIPT})
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


# ******************  Initializing submodules

git submodule init

# ******************  Cleaning up build tree

if [ ! -d ${BUILDDIR} ]; then
	mkdir -p ${BUILDDIR};
fi;


# ******************  Compile rkflashtool
( cd ${DIR}/submodules/rkflashtool && make && cd - )


# ******************  Adding in the unknowns

cp -f ${DIR}/parts/unknown.1 ${BUILDDIR}/unknown.1
cp -f ${DIR}/parts/unknown.2 ${BUILDDIR}/unknown.2

# ******************  CRC the parameters

${RKCRC} -p ${DIR}/parts/parameters ${BUILDDIR}/parameters.img

# ******************  Encrypt the headers

KEY=7C4E0304550509072D2C7B38170D1711
openssl rc4 -K ${KEY} < ${DIR}/parts/sd_header.1 > ${BUILDDIR}/sd_header.1.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/sd_header.2 > ${BUILDDIR}/sd_header.2.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/FlashBoot.bin > ${BUILDDIR}/FlashBoot.bin.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/FlashData.bin > ${BUILDDIR}/FlashData.bin.rc4


# ******************  Make the boot image


${RKCRC} -k ${BUILDDIR}/Image ${BUILDDIR}/Image.krn
${RKCRC} -k ${BUILDDIR}/initramfs.igz ${BUILDDIR}/initramfs.igz.krn


