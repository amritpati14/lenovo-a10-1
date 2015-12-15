#!/usr/bin/env bash

set -e

SCRIPT=$0
DIR=$(dirname ${SCRIPT})

if [ ! -r ${DIR}/config ]; then
	echo "Please copy config.example to config, check it, and run this again."
	exit -1
fi;

source ${DIR}/config

BUILDDIR=${DIR}/${BUILD}

RKFLASHTOOL=${DIR}/submodules/rkflashtool/rkflashtool

SHELL=$(which bash)


git submodule init

mkdir -p ${BUILDDIR}
mkdir -p ${BUILDDIR}/initramfs


# Compile rkflashtool
( cd ${DIR}/submodules/rkflashtool && \
	make && \
	cd - )

# Compile uboot

( cd ${DIR}/submodules/u-boot-rockchip && \
	git checkout u-boot-rk3188-sdcard && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk30xx_config && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk30xx && \
	cd - )

cp -f ${DIR}/submodules/u-boot-rockchip/RK3188Loader_uboot.bin ${BUILDDIR}


echo "Configuring and compiling the kernel and modules"

( cd ${DIR}/kernel && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make rk3188_flex10_defconfig && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules && \
	cd - )


#cp -f kernel/arch/arm/boot/


# Creating the initramfs

(
	mkdir -p ${BUILDDIR}/initramfs/{bin,sbin,etc,proc,sys,newroot}
	touch ${BUILDDIR}/initramfs/etc/mdev.conf
	cp -rf ${DIR}/parts/initramfs/* ${BUILDDIR}/initramfs/
	find . | cpio -H newc -o > ${BUILDDIR}/initramfs.cpio
	cat ${BUILDDIR}/initramfs.cpio | gzip > ${BUILDDIR}/initramfs.igz
	cd -
)















