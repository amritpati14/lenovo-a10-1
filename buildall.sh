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
INITDIR=${BUILDDIR}/initramfs

RKFLASHTOOL=${DIR}/submodules/rkflashtool/rkflashtool
RKCRC=${DIR}/submodules/rkflashtool/rkcrc
UNPACK=${DIR}/submodules/rk3066-rom-scripts/unpack_loader.pl


git submodule init

mkdir -p ${BUILDDIR}
mkdir -p ${BUILDDIR}/initramfs


# Compile rkflashtool
( cd ${DIR}/submodules/rkflashtool && \
	make && \
	cd - )

# Compile uboot

#( cd ${DIR}/submodules/u-boot-rockchip && \
#	git checkout u-boot-rk3188-sdcard && \
#	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk30xx_config && \
#	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk30xx && \
#	cd - )

# cp -f ${DIR}/parts/RK3188Loader_V1.20.bin ${BUILDDIR}/RK3188Loader.bin

echo "Configuring and compiling the kernel and modules"

( cd ${DIR}/kernel && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk3188_flex10_defconfig && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules_install INSTALL_MOD_PATH=${INITDIR} && \
	cd - )


cp -f ${DIR}/kernel/arch/arm/boot/Image ${BUILDDIR}/


# Creating the initramfs

(
	mkdir -p ${INITDIR}/{bin,sbin,etc,proc,sys,newroot}
	touch ${INITDIR}/etc/mdev.conf
	cp -rf ${DIR}/parts/initramfs/* ${INITDIR}/
	cd ${INITDIR}
	find . | cpio -H newc -o > ${BUILDDIR}/initramfs.cpio
	cat ${BUILDDIR}/initramfs.cpio | gzip > ${BUILDDIR}/initramfs.igz
	cd -
)


cp -f ${DIR}/parts/unknown.1 ${BUILDDIR}/unknown.1
cp -f ${DIR}/parts/unknown.2 ${BUILDDIR}/unknown.2


${RKCRC} -p ${DIR}/parts/parameters ${BUILDDIR}/parameters.img
${RKCRC} -k ${BUILDDIR}/initramfs.igz ${BUILDDIR}/boot.img
${RKCRC} -k ${BUILDDIR}/Image ${BUILDDIR}/kernel.img


openssl rc4 -K ${KEY} < ${DIR}/parts/sd_header.1 > ${BUILDDIR}/sd_header.1.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/sd_header.2 > ${BUILDDIR}/sd_header.2.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/FlashBoot.bin > ${BUILDDIR}/FlashBoot.bin.rc4
openssl rc4 -K ${KEY} < ${DIR}/parts/FlashData.bin > ${BUILDDIR}/FlashData.bin.rc4

#cd ${BUILDDIR} && ${UNPACK} ./RK3188Loader.bin write && cd -
#openssl rc4 -K ${KEY} < ${BUILDDIR}/3188_LPDDR2_300MHz_.bin > ${BUILDDIR}/3188_LPDDR2_300MHz_.bin.rc4
#openssl rc4 -K ${KEY} < ${BUILDDIR}/rk30usbplug.bin > ${BUILDDIR}/rk30usbplug.bin.rc4





