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

# ******************  Displaying information

echo "Building SD card for Lenovo flip A10 with the following settings:"
echo
echo "ARCH = ${ARCH}"
echo "CROSS_COMPILE = ${CROSS_COMPILE}"
echo "LINUX = ${LINUX}"
echo
echo "Build directory = ${BUILDDIR}"
echo "Initramfs build directory = ${INITRAMFSOUT}"
echo

echo "Are you happy with these settings? (Y/n)";
read JANEE
if [ "z${JANEE}" != "zY" ]; then
	echo "stopping";
	exit -1;
fi;


# ******************  Check for the existence of some files

if [ ! -r ${KCONFIG} ]; then
	echo "ERROR - can't open kernel config: ${KCONFIG}";
	exit -1;
fi;

if [ ! -d ${KERNEL} ]; then
	echo "ERROR - kernel directory not found: ${KERNEL}";
	exit -1;
fi;


# ******************  Check for executables

GCC=`which ${CROSS_COMPILE}gcc`
if [ $? != 0 ]; then
	echo "Unable to locate crosscompiler: ${CROSS_COMPILE}gcc";
	exit -1;
fi;

if [ ! -x ${GCC} ]; then
	echo "Unable to execute gcc: ${CROSS_COMPILE}gcc";
	exit -1;
fi


# ******************  Initializing submodules

git submodule init

# ******************  Cleaning up build tree

if [ -d ${INITRAMFSOUT} ]; then

	echo "${INITRAMFSOUT} is about to be removed. Proceed? (Y/n)";
	read JANEE
	if [ "z${JANEE}" != "zY" ]; then
		echo "stopping";
		exit -1;
	fi;

	rm -rf ${INITRAMFSOUT}/
fi;

if [ -d ${BUILDDIR} ]; then

	echo "${BUILDDIR} is about to be removed. Proceed? (Y/n)";
	read JANEE
	if [ "z${JANEE}" != "zY" ]; then
		echo "stopping";
		exit -1;
	fi;

	rm -rf ${BUILDDIR}/
fi;


# ******************  Creating build tree

mkdir -p ${BUILDDIR}
mkdir -p ${INITRAMFSOUT}/



# ******************  Compile rkflashtool
( cd ${DIR}/submodules/rkflashtool && make && cd - )


# ******************  Compile the kernel and modules

echo "Configuring and compiling the kernel and modules"

( cd ${KERNEL} && \
	cp ${KCONFIG} ${KERNEL}/.config && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules_install INSTALL_MOD_PATH=${INITRAMFSOUT} && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make firmware_install INSTALL_MOD_PATH=${INITRAMFSOUT} && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make headers_install INSTALL_HDR_PATH=${INITRAMFSOUT}/usr/ && \
	cd - )


cp -f ${KERNEL}/arch/arm/boot/Image ${BUILDDIR}/


# ******************  Creating the initramfs

(
	cp -rf ${DIR}/initramfs/* ${INITRAMFSOUT}/
	cd ${INITRAMFSOUT}
	find . | cpio -H newc -o > ${BUILDDIR}/initramfs.cpio
	cat ${BUILDDIR}/initramfs.cpio | gzip -9 > ${BUILDDIR}/initramfs.igz
	cd -
)

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


# ******************  Create the images - NAND and SD card


exec ${DIR}/makeimages.sh




