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

if [ ! -r ${KCONFIG} ]; then
	echo "ERROR - can't open kernel config: ${KCONFIG}";
	exit -1;
fi;

if [ ! -d ${KERNEL} ]; then
	echo "ERROR - kernel directory not found: ${KERNEL}";
	exit -1;
fi;


# ******************  Initializing submodules

echo "Configuring and compiling the kernel and modules"

( cd ${KERNEL} && \
	cp ${KCONFIG} ${KERNEL}/.config && \
	ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make distclean && \
	cd - )





