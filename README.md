# lenovo-a10
Official Lenovo Ideapad/Multimode A10 Laptop releases


ARCH=arm
export ARCH

CROSS_COMPILE=arm=none-eabi-
export CROSS_COMPILE


make rk3188_flex10_defconfig

make
make modules





