#!/usr/bin/env bash


# ******************  Any error is a bad error. Die immediately

set -e


# ****************** Load up configurations

BASE=$(readlink -f `dirname $0`)
BUILD=`pwd`


ARCH="arm"
CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-"



function setup_vars {

	SRCDIR=${BUILD}/src/code
	REPODIR=${BUILD}/src/repos
	LOCALDIR=${BUILD}/local
	WORKDIR=${BUILD}/work
	INITRAMFSDIR=${BUILD}/initramfs
	
	PRODUCTSDIR=${BUILD}/products

	EXTCONFIGS=${BASE}/extconfigs
}

function prep_directories {

	mkdir -p ${SRCDIR}
	mkdir -p ${REPODIR}
	mkdir -p ${LOCALDIR}
	mkdir -p ${WORKDIR}
	mkdir -p ${INITRAMFSDIR}
	mkdir -p ${PRODUCTSDIR}

	eval "$1=0"
}

function download_source {
	URL=$2
	( cd ${SRCDIR} && wget -q --show-progress -c ${URL} && cd ${OLDPWD} )
	eval "$1=$?"
}

function clone_repo {
	URL=$3
	NAME=$2
	if [ ! -d ${REPODIR}/${NAME} ]; then
		( cd ${REPODIR} && git clone --progress ${URL} && cd ${OLDPWD} )
	fi;
	eval "$1=$?"
}


function build_crosstools {

	( cd ${REPODIR}/crosstool-ng &&	\
		./bootstrap && \
		./configure --prefix=${LOCALDIR} &&	\
		make &&	\
		make install &&	\
		cd ${OLDPWD}
	)
		
	eval "$1=$?"
}

function build_crosschain {

	mkdir -p ${WORKDIR}/crosschain


	( cd ${WORKDIR}/crosschain &&	\
		${LOCALDIR}/bin/ct-ng arm-cortexa9_neon-linux-gnueabihf &&	\
		cp -f ${EXTCONFIGS}/crosstools-linux-4.9-rc8 ${WORKDIR}/crosschain/.config &&	\
		KERNELDIR=${WORKDIR}/linux-4.9-rc8		\
		KERNELVERSION=4.9-rc8		\
		SRCDIR=${SRCDIR}			\
		LOCALDIR=${LOCALDIR}		\
		${LOCALDIR}/bin/ct-ng build && \
		cd ${OLDPWD}
	)
		
	eval "$1=$?"
}

function build_busybox {

	NAME=$2

	( cd ${WORKDIR}/${NAME} &&	\
		cp -f ${EXTCONFIGS}/${NAME} ${WORKDIR}/${NAME}/.config &&	\
		KERNELDIR=${WORKDIR}/linux-4.9-rc8		\
		KERNELVERSION=4.9-rc8		\
		SRCDIR=${SRCDIR}			\
		LOCALDIR=${LOCALDIR}		\
		INITRAMFSDIR=${INITRAMFSDIR}		\
		make &&			\
		KERNELDIR=${WORKDIR}/linux-4.9-rc8		\
		KERNELVERSION=4.9-rc8		\
		SRCDIR=${SRCDIR}			\
		LOCALDIR=${LOCALDIR}		\
		INITRAMFSDIR=${INITRAMFSDIR}		\
		make CONFIG_PREFIX=${INITRAMFSDIR} install &&			\
		cd ${OLDPWD}
	)
		
	eval "$1=$?"
}

function populate_crosschain {

	( cd ${INITRAMFSDIR} &&	\
		arm-cortexa9_neon-linux-gnueabihf-populate -m -s ${LOCALDIR}/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/ -d .	&&	\
		cd ${OLDPWD}
	)

	eval "$1=$?"
}

function build_kernel {

	NAME=$2

	( cd ${WORKDIR}/${NAME} &&	\
		cp -f ${EXTCONFIGS}/${NAME} ${WORKDIR}/${NAME}/.config &&	\
		ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make && \
		ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules && \
		ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make modules_install INSTALL_MOD_PATH=${INITRAMFSDIR} && \
		ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make firmware_install INSTALL_MOD_PATH=${INITRAMFSDIR} && \
		ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make headers_install INSTALL_HDR_PATH=${INITRAMFSDIR} && \
		cp -f ${WORKDIR}/${NAME}/arch/arm/boot/Image ${PRODUCTSDIR}	\
		cd ${OLDPWD}
	)
		
	eval "$1=$?"
}


function extras_for_initramfs {

	cp -f ${BASE}/parts/init ${INITRAMFSDIR}

	eval "$1=$?"
}




function extract_kernel {
	tar -xJvf ${SRCDIR}/$2 -C ${WORKDIR}
	eval "$1=$?"
}

function extract_busybox {
	tar -xjvf ${SRCDIR}/$2 -C ${WORKDIR}
	eval "$1=$?"
}

function compress_initramfs {

	( cd ${INITRAMFSDIR} &&	\
		find . | cpio -H newc -R +0:+0 -o | gzip -9 > ${PRODUCTSDIR}/initramfs.igz && \
		cd ${OLDPWD}
	)
		
	eval "$1=$?"
}

function build_submodule {
	NAME=$2
	( cd ${REPODIR}/${NAME} && make  && cd ${OLDPWD} )
	eval "$1=$?"
}

function prep_files {

	cp ${BASE}/parts/unknown.{1,2} ${PRODUCTSDIR}/

	# ******************  Encrypt the headers

	KEY=7C4E0304550509072D2C7B38170D1711
	openssl rc4 -K ${KEY} < ${BASE}/parts/sd_header.1 > ${PRODUCTSDIR}/sd_header.1.rc4
	openssl rc4 -K ${KEY} < ${BASE}/parts/sd_header.2 > ${PRODUCTSDIR}/sd_header.2.rc4
	openssl rc4 -K ${KEY} < ${BASE}/parts/FlashBoot.bin > ${PRODUCTSDIR}/FlashBoot.bin.rc4
	openssl rc4 -K ${KEY} < ${BASE}/parts/FlashData.bin > ${PRODUCTSDIR}/FlashData.bin.rc4

	${RKCRC} -p ${BASE}/parts/parameters ${PRODUCTSDIR}/parameters.img
	${RKCRC} -k ${PRODUCTSDIR}/Image ${PRODUCTSDIR}/Image.krn
	${RKCRC} -k ${PRODUCTSDIR}/initramfs.igz ${PRODUCTSDIR}/initramfs.igz.krn


	eval "$1=$?"
}


function build_images {

	OFILESD=${PRODUCTSDIR}/rk3188_sdboot.img
	OFILENAND=${PRODUCTSDIR}/rk3188_nand.img

	rm -f ${OFILESD} ${OFILENAND}


	dd if=/dev/zero of=${OFILESD} conv=sync,fsync \
		bs=512 count=8192

	dd if=${PRODUCTSDIR}/sd_header.1.rc4 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=64
	dd if=${PRODUCTSDIR}/sd_header.2.rc4 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=65

	dd if=${PRODUCTSDIR}/FlashData.bin.rc4 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=68
	dd if=${PRODUCTSDIR}/FlashBoot.bin.rc4 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=92

	# ----------------

	dd if=${PRODUCTSDIR}/unknown.1 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=8064

	dd if=${PRODUCTSDIR}/unknown.2 of=${OFILESD} conv=notrunc,sync,fsync \
		bs=512 seek=8065

	# ----------------

	# Less than 16 MB!!
	dd if=${PRODUCTSDIR}/Image.krn of=${OFILESD} conv=notrunc,sync,fsync \
		seek=$((0x2000 + 0x4000))

	# Less than 64 MB!!
	dd if=${PRODUCTSDIR}/initramfs.igz.krn of=${OFILESD} conv=notrunc,sync,fsync \
		seek=$((0x2000 + 0xC000))


	# ----------------
	# And here they differ so we copy them

	cp ${OFILESD} ${OFILENAND}

	# ----------------


	# On the SD image, put the parameters at block 64

	dd if=${PRODUCTSDIR}/parameters.img of=${OFILESD} conv=notrunc,sync,fsync \
		seek=$((0x2000))


	# On the NAND image, put the parameters at block 0

	dd if=${PRODUCTSDIR}/parameters.img of=${OFILENAND} conv=notrunc,sync,fsync \
		seek=$((0x0000))


	eval "$1=$?"
}





RC=0

setup_vars RC;
prep_directories RC

download_source RC https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-4.9-rc8.tar.xz
download_source RC https://www.busybox.net/downloads/busybox-1.25.1.tar.bz2
clone_repo RC crosstool-ng https://github.com/crosstool-ng/crosstool-ng
clone_repo RC rkflashtool https://github.com/durandmiller/rkflashtool.git
clone_repo RC rockchip-mkbootimg https://github.com/durandmiller/rockchip-mkbootimg.git

build_submodule RC rkflashtool
build_submodule RC rockchip-mkbootimg

export RKCRC=${REPODIR}/rkflashtool/rkcrc
export RKPAD=${REPODIR}/rkflashtool/rkpad

build_crosstools RC

export PATH=${LOCALDIR}/bin:${PATH}

extract_kernel RC linux-4.9-rc8.tar.xz

build_crosschain RC

export PATH=${LOCALDIR}/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:${PATH}


extract_busybox RC busybox-1.25.1.tar.bz2
build_busybox RC busybox-1.25.1

populate_crosschain RC

build_kernel RC linux-4.9-rc8

extras_for_initramfs RC
compress_initramfs RC

prep_files RC

build_images RC

exit 0



