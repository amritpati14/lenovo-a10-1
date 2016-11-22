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


LDFLAGS="-nostdlib -L${INITRAMFSOUT}/lib/arm-linux-gnueabihf/ -L${INITRAMFSOUT}/lib/"

CFLAGS="-nostdlib -nostdinc -I${INITRAMFSOUT}/usr/include/"



ARCH=${ARCH}							\
CROSS_COMPILE=${CROSS_COMPILE}			\
../src/configure						\
	--prefix=${INITRAMFSOUT}			\
	--host=${HOST}						\
	--target=${HOST}						\
	CC=${CROSS_COMPILE}gcc				\
	LDFLAGS="${LDFLAGS}"				\
	CFLAGS="${CFLAGS}"




