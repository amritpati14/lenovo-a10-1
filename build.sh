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

	EXTCONFIGS=${BASE}/extconfigs
}

function prep_directories {

	mkdir -p ${SRCDIR}
	mkdir -p ${REPODIR}
	mkdir -p ${LOCALDIR}
	mkdir -p ${WORKDIR}
	mkdir -p ${INITRAMFSDIR}

	eval "$1=0"
}

function download_source {
	URL=$2
	( cd ${SRCDIR} && wget -q --show-progress -c ${URL} && cd ${OLDPWD} )
	eval "$1=$?"
}

function clone_repo {
	URL=$2
	if [ ! -d ${REPODIR}/crosstool-ng ]; then
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
		cd ${OLDPWD}
	)
		
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






RC=0

setup_vars RC;
prep_directories RC

#download_source RC https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-4.9-rc8.tar.xz
#download_source RC https://www.busybox.net/downloads/busybox-1.25.1.tar.bz2
#clone_repo RC https://github.com/crosstool-ng/crosstool-ng

#build_crosstools RC

export PATH=${LOCALDIR}/bin:${PATH}

#extract_kernel RC linux-4.9-rc8.tar.xz

#build_crosschain RC

export PATH=${LOCALDIR}/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:${PATH}


# extract_busybox RC busybox-1.25.1.tar.bz2
# build_busybox RC busybox-1.25.1

# populate_crosschain RC

build_kernel RC linux-4.9-rc8

exit 0;



