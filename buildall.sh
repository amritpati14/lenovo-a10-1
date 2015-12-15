#!/usr/bin/env bash

PWD=$(pwd)

SCRIPT=$0
DIR=$(dirname ${SCRIPT})



echo "Configuring and compiling the kernel and modules"

cd ${DIR}/kernel && make rk3188_flex10_defconfig && make && make modules && cd -



