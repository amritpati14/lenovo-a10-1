# Linux on the Lenovo A10 Multimode Laptop



## Design and Layout

### Scripts



## Building

### Building the crossover toolchain


'''
crosstools-ng
arm-cortexa9_neon-linux-gnueabihf

mkdir ~/path/to/toolchain/dir
go there
ct-ng arm-cortexa9_neon-linux-gnueabihf
ct-ng menuconfig
ct-ng build
'''


### Installing the toolchain


### Building the kernel

multi_v7_defconfig

### Building the initramfs

### Building the SD card image

## Booting

## Installing onto the internal disk








# lenovo-a10
Official Lenovo Ideapad/Multimode A10 Laptop releases


make
make modules

dd if=sdboot_rk3188.img of=/dev/XXX conv=sync,fsync
dd if=parameter.img of=/dev/XXX conv=sync,fsync seek=$((0x2000))
dd if=kernel.img of=/dev/XXX conv=sync,fsync seek=$((0x2000+0x4000))
dd if=boot.img of=/dev/XXX conv=sync,fsync seek=$((0x2000+0xc000))


NEW

file systems - network - coda
scsi - low level - aic7xxx
drivers - graphics - radeon


http://crosstool-ng.org/


4.9 kernel
no gdb



video=U:1368x768-16@







