

include ./config


# ------------------------------------------------------

OFILESD=$(PRODUCTSDIR)/rk3188_sdboot.img

# ------------------------------------------------------


PRODUCTSDIR=$(BUILD)/products
INITRAMFSDIR=$(BUILD)/initramfs
LOCALDIR=$(BUILD)/local
WORKDIR=$(BUILD)/work

OVERLAYDIR=$(BASE)/overlays
REPODIR=$(BUILD)/repos
CODEDIR=$(SRCDIR)

RKCRC=$(REPODIR)/rkflashtool/rkcrc

KEY=7C4E0304550509072D2C7B38170D1711

ADDR=zreladdr-y=0x60408000  params_phys-y=0x60088000 initrd_phys-y=0x60800000


# ------------------------------------------------------




.PHONY: directories $(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(PRODUCTSDIR)/initramfs.md5.new


all: directories $(OFILESD)
	@RELLINK=$(shell realpath --relative-to=$(BUILD) $(OFILESD) ) && \
	echo "Success. Product is $${RELLINK}"


$(REPODIR)/ $(CODEDIR)/ $(PRODUCTSDIR)/ $(LOCALDIR)/ $(WORKDIR)/crosschain/:
	mkdir -p $@


$(INITRAMFSDIR)/:
	cp -rf $(OVERLAYDIR)/initramfs $(INITRAMFSDIR)


directories: $(REPODIR)/ $(CODEDIR)/ $(PRODUCTSDIR)/ $(LOCALDIR)/ $(INITRAMFSDIR)/ $(WORKDIR)/crosschain/


$(REPODIR)/rkflashtool/README:
	cd $(REPODIR) && git clone $(RKFLASHTOOL_URL) && cd $(BUILD)


$(RKCRC): $(REPODIR)/rkflashtool/README
	$(MAKE) -C $(REPODIR)/rkflashtool/



# ---- BUSYBOX -----------------------------------------


$(CODEDIR)/busybox-$(BUSYBOX).tar.bz2:
	cd $(CODEDIR) && wget -c $(BUSYBOX_URL) && cd $(BUILD)

$(WORKDIR)/busybox-$(BUSYBOX)/README: $(CODEDIR)/busybox-$(BUSYBOX).tar.bz2
	tar --touch -xjvf $< -C $(WORKDIR)

$(WORKDIR)/busybox-$(BUSYBOX)/.config: $(BASE)/extconfigs/busybox-$(KERNEL_VERSION)
	cp -f $< $@

$(WORKDIR)/busybox-$(BUSYBOX)/busybox: $(WORKDIR)/busybox-$(BUSYBOX)/README $(WORKDIR)/busybox-$(BUSYBOX)/.config $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc
	cd $(WORKDIR)/busybox-$(BUSYBOX) &&	\
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH \
	KERNELDIR=$(WORKDIR)/$(KERNEL)		\
	KERNELVERSION=$(KERNEL_VERSION)	\
	SRCDIR=$(CODEDIR)		\
	LOCALDIR=$(LOCALDIR)	\
	INITRAMFSDIR=$(INITRAMFSDIR)	\
	make && \
	cd $(BUILD)



$(INITRAMFSDIR)/bin/busybox: $(WORKDIR)/busybox-$(BUSYBOX)/busybox
	cd $(WORKDIR)/busybox-$(BUSYBOX) && \
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH \
	KERNELDIR=$(WORKDIR)/$(KERNEL)		\
	KERNELVERSION=$(KERNEL_VERSION)	\
	SRCDIR=$(CODEDIR)		\
	LOCALDIR=$(LOCALDIR)	\
	INITRAMFSDIR=$(INITRAMFSDIR)	\
	make CONFIG_PREFIX=$(INITRAMFSDIR) install && \
	rm -f $(INITRAMFSDIR)/linuxrc && \
	cd $(BUILD)


# ---- CROSSTOOLS AND CROSSCHAIN -----------------------


$(REPODIR)/crosstool-ng/bootstrap:
	cd $(REPODIR) && git clone $(CTNG_URL) && cd $(BUILD)


$(REPODIR)/crosstool-ng/ct-ng: $(REPODIR)/crosstool-ng/bootstrap
	cd $(REPODIR)/crosstool-ng && ./bootstrap && \
	./configure --prefix=$(LOCALDIR) &&	MAKELEVEL=0 make && cd $(BUILD)


$(LOCALDIR)/bin/ct-ng: $(REPODIR)/crosstool-ng/ct-ng
	cd $(REPODIR)/crosstool-ng && MAKELEVEL=0 make install && cd $(BUILD)


$(WORKDIR)/crosschain/.config: $(BASE)/extconfigs/crosstools-$(KERNEL)
	cd $(WORKDIR)/crosschain && \
	$(LOCALDIR)/bin/ct-ng arm-cortexa9_neon-linux-gnueabihf && \
	cp -f $(BASE)/extconfigs/crosstools-$(KERNEL) $(WORKDIR)/crosschain/.config && \
	cd $(BUILD)


$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc: $(LOCALDIR)/bin/ct-ng $(WORKDIR)/crosschain/.config
	cd $(WORKDIR)/crosschain && \
	KERNELDIR=$(WORKDIR)/$(KERNEL)	\
	KERNELVERSION=$(KERNEL_VERSION)	\
	SRCDIR=$(CODEDIR)	\
	LOCALDIR=$(LOCALDIR)	\
	$(LOCALDIR)/bin/ct-ng build && \
	cd $(BUILD)


# ---- POPULATE ----------------------------------------

$(INITRAMFSDIR)/lib/ld-linux-armhf.so.3: $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/lib/ld-linux-armhf.so.3
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH && \
	cd $(INITRAMFSDIR) && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/lib/ -d ./lib/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/sbin/ -d ./sbin/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/etc/ -d ./etc/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/var/ -d ./var/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/bin/ -d ./usr/bin/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/include/ -d ./usr/include/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/lib/ -d ./usr/lib/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/libexec/ -d ./usr/ibexec/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/sbin/ -d ./usr/sbin/ && \
	arm-cortexa9_neon-linux-gnueabihf-populate -m -s $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/arm-cortexa9_neon-linux-gnueabihf/sysroot/usr/share -d ./usr/share/ && \
	cd $(BUILD)


# ---- LINUX KERNEL AND ETC ----------------------------


$(CODEDIR)/$(KERNEL).tar.$(KERNEL_TYPE):
	cd $(CODEDIR) && wget -c $(KERNEL_URL)


$(WORKDIR)/$(KERNEL)/README: $(CODEDIR)/$(KERNEL).tar.$(KERNEL_TYPE)
	mkdir -p $(WORKDIR)/$(KERNEL) &&	\
	tar --strip-components=1 --touch -x$(KERNEL_EXTRACT)vf $< -C $(WORKDIR)/$(KERNEL)


$(WORKDIR)/$(KERNEL)/.config: $(WORKDIR)/$(KERNEL)/README $(BASE)/extconfigs/$(KERNEL)
	cp -f $(BASE)/extconfigs/$(KERNEL) $@


$(WORKDIR)/$(KERNEL)/arch/arm/boot/zImage: $(WORKDIR)/$(KERNEL)/.config $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc $(INITRAMFSDIR)/
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH && \
	cd $(WORKDIR)/$(KERNEL) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make ${ADDR} && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules $(ADDR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules_install INSTALL_MOD_PATH=$(INITRAMFSDIR) $(ADDR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make firmware_install  INSTALL_MOD_PATH=$(INITRAMFSDIR) $(ADDR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make headers_install INSTALL_HDR_PATH=$(INITRAMFSDIR) $(ADDR) && \
	cd $(BUILD)



$(PRODUCTSDIR)/zImage: $(WORKDIR)/$(KERNEL)/arch/arm/boot/zImage
	dd if=$< of=$@ bs=4096 conv=sync 2>/dev/null


$(INITRAMFSDIR)/lib/modules/$(DEP_VERSION)/modules.dep: $(PRODUCTSDIR)/zImage



# ---- Initramfs rules ------------------------------------

$(INITRAMFSDIR)/init: $(BASE)/parts/init-$(KERNEL_VERSION)
	cp -f $< $@


$(PRODUCTSDIR)/initramfs.md5.new:
	@find $(INITRAMFSDIR) | md5sum | awk '{ print $$1 }' > $@

$(PRODUCTSDIR)/initramfs.md5: $(PRODUCTSDIR)/initramfs.md5.new
	@diff $@ $@.new > /dev/null; \
	if [ "z$$?" != "z0" ]; then \
		cp -f $< $@; \
	fi

$(PRODUCTSDIR)/initramfs.igz: $(INITRAMFSDIR)/init $(INITRAMFSDIR)/bin/busybox $(INITRAMFSDIR)/lib/modules/$(DEP_VERSION)/modules.dep $(INITRAMFSDIR)/lib/ld-linux-armhf.so.3 $(PRODUCTSDIR)/initramfs.md5
	cd $(INITRAMFSDIR) && \
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > $@ && \
	cd $(BUILD)


# ---- Product signing ------------------------------------


$(PRODUCTSDIR)/%.rc4: $(BASE)/parts/%
	openssl rc4 -K $(KEY) < $< > $@

$(PRODUCTSDIR)/unknown.%: $(BASE)/parts/unknown.%
	cp $< $@

$(PRODUCTSDIR)/zImage.krn: $(PRODUCTSDIR)/zImage $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/zImage $@

$(PRODUCTSDIR)/initramfs.igz.krn: $(PRODUCTSDIR)/initramfs.igz $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/initramfs.igz $@

$(PRODUCTSDIR)/parameters.img: $(BASE)/parts/parameters-$(KERNEL_VERSION) $(RKCRC)
	$(RKCRC) -p $(BASE)/parts/parameters $@

# ---------------------------------------------------------


# ---- We create an SD image of 128 MB and populate it with all the parts
#      Kernel <= 32MB
#      Initramfs <= 128MB

$(OFILESD): $(PRODUCTSDIR)/sd_header.1.rc4 $(PRODUCTSDIR)/sd_header.2.rc4 $(PRODUCTSDIR)/FlashData.bin.rc4 $(PRODUCTSDIR)/FlashBoot.bin.rc4 $(PRODUCTSDIR)/unknown.1 $(PRODUCTSDIR)/unknown.2 $(PRODUCTSDIR)/zImage.krn $(PRODUCTSDIR)/initramfs.igz.krn $(PRODUCTSDIR)/parameters.img
	@SIZE=`stat -c%s "$(PRODUCTSDIR)/zImage.krn"` && if [ $$SIZE -gt 33554432 ]; then echo "Kernel too big. Adjust parameters file and makefile"; exit 1; fi;
	@SIZE=`stat -c%s "$(PRODUCTSDIR)/initramfs.igz.krn"` && if [ $$SIZE -gt 134217728 ]; then echo "Initramfs too big. Adjust parameters file and makefile."; exit 1; fi;
	dd if=/dev/zero of=$(OFILESD) conv=sync,fsync bs=512 count=262144
	dd if=$(PRODUCTSDIR)/sd_header.1.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=64
	dd if=$(PRODUCTSDIR)/sd_header.2.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=65
	dd if=$(PRODUCTSDIR)/FlashData.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=68
	dd if=$(PRODUCTSDIR)/FlashBoot.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=92
	dd if=$(PRODUCTSDIR)/unknown.1 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8064
	dd if=$(PRODUCTSDIR)/unknown.2 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8065
	dd if=$(PRODUCTSDIR)/zImage.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0x4000))
	dd if=$(PRODUCTSDIR)/initramfs.igz.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0x14000))
	dd if=$(PRODUCTSDIR)/parameters.img of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000))




