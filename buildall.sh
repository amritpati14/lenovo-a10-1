#!/usr/bin/env bash

set -e

SCRIPT=$0
DIR=$(dirname ${SCRIPT})

if [ ! -r ${DIR}/config ]; then
	echo "Please copy config.example to config, check it, and run this again."
	exit -1
fi;

source ${DIR}/config



git submodules init


# Compile rkflashtool
cd ${DIR}/submodules/rkflashtool && make && cd -

# Compile uboot

echo ${ARCH} ${CROSS_COMPILE}

exit 0;
         


cd ${DIR}/submodules/


echo "Configuring and compiling the kernel and modules"

cd ${DIR}/kernel && make rk3188_flex10_defconfig && make && make modules && cd -



