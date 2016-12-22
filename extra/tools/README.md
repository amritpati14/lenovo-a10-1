Originally from: https://gist.github.com/sarg/5028505
--------------------------------------------------------


Obtaining RK3066 boot ROM.
==========================

Here are my steps.

At first, I took a look to **RK30xxLoader(L)_V1.18.bin**. This file appears in update.img for my device.
So, I unpacked update.img using rk29Kitchen.

`strings` on that file returns nothing interesting, so I assumed the file is crypted

Next step was to get IDA pro, and disassemble *RKAndroidTool.fexe* - utility from rockchip for flashing device firmware. In disassembly I found, that loader is scrambled using RC4. File is split to 0x200 chunks and every chunk is scrambled.

So, I wrote **unpack_loader.pl** script, which gave me output of 4 files.

    1   14a  321c 30_LPDDR2_300MHz_DD
    2  3366  c914 rk30usbplug
    4  fc7a  3400 FlashData
    4 1307a 1ac00 FlashBoot

Fortunately, there were meaningful names for those files in loader.bin.

**30_LPDDR2_300MHz_DD** is a dram init procedure
**FlashData** is a copy of dram init procedure, aligned to 512 bytes (flash block size)

**rk30usbplug** is MaskRom mode handler
**FlashBoot** is stage2 for booting from NAND, and also it contains handler for DFU mode.

Those files were disassembled too, and in FlashBoot I found that there is command in DFU mode to obtain data from any DDR RAM region. So, my idea was to inject code in FlashBoot, which will copy bootrom to some address, accessible in DFU mode. But there was a problem, FlashBoot is overwriting memory at address 0 - it is where bootrom is located at power on. So, all I need is to copy 0x2800 bytes (boot ROM size) starting from 0x0 before FlasfhBoot overwrites it, and there you are -> **bootrom.bin**

So I wrote a set of tools for that.
**patch_loader.sh** injects code
**pack_loader.pl** resembles lFoader from parts and sign it with rkcrc.

So, all was done with this script.

```
perl unpack_loader.pl RK30xxLoader\(L\)_V1.18.bin write
sh patch_loader.sh FlashBoot.bin
perl pack_loader.pl dram=30_LPDDR2_300MHz_DD.bin boot=FlashBoot.bin.patched data=FlashData.bin usbplug=rk30usbplug.bin out=patchedLoader.bin
```

Flash patchedLoader.bin with RKAndroidTool.exe, and obtain loader with
`rkflashtool m 0x64000000 0x2800 > bootrom.bin`

I uploaded **bootrom.hex**.
Execute `xxd -rp bootrom.hex > bootrom.bin` to get bootrom.bin

Now, when all parts of loader are descrambled and could be disassembled, it is matter of time to port u-boot to this SoC, and boot any OS native.


RK3066 boot sequence
====================

At power, rk30 starts from 0x0 offset in bootrom.  

bootrom copies itself to SRAM, and proceeds to find dram init handler in idbrom  
bootrom loads dram init handler in memory and executes it  
bootroms search for flashboot and load it to memory  
if flashboot could not be found, bootrom search for usbplug and load it  

flashboot init NAND, search for parameter file, load kernel to DRAM and boot it  
