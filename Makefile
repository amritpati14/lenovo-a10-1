

include ./config


PRODUCTSDIR=$(BUILD)/products
INITRAMFSDIR=$(BUILD)/initramfs
LOCALDIR=$(BUILD)/local
WORKDIR=$(BUILD)/work


REPODIR=$(SRCDIR)/repos
CODEDIR=$(SRCDIR)/code

RKCRC=$(REPODIR)/rkflashtool/rkcrc


KEY=7C4E0304550509072D2C7B38170D1711




OFILESD=$(PRODUCTSDIR)/rk3188_sdboot.img
OFILENAND=$(PRODUCTSDIR)/rk3188_nand.img



.PHONY: directories $(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(PRODUCTSDIR)/initramfs.md5.new


all: directories $(OFILESD)
	@echo "fin"


$(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(WORKDIR)/crosschain:
	mkdir -p $@

directories: $(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(WORKDIR)/crosschain


$(REPODIR)/rkflashtool:
	cd $(REPODIR) && \
		git clone https://github.com/durandmiller/rkflashtool.git &&	\
	cd $(BUILD)


$(RKCRC): $(REPODIR)/rkflashtool
	$(MAKE) -C $(REPODIR)/rkflashtool/


# ------------------------------------------------------

#populate crosschain


# ---- BUSYBOX -----------------------------------------


$(CODEDIR)/busybox-1.25.1.tar.bz2:
	cd $(CODEDIR) && wget -c https://www.busybox.net/downloads/busybox-1.25.1.tar.bz2 && cd $(BUILD)

$(WORKDIR)/busybox-1.25.1: $(CODEDIR)/busybox-1.25.1.tar.bz2
	tar -xZvf $< -C $(WORKDIR)

$(WORKDIR)/busybox-1.25.1/.config: $(BASE)/extconfigs/busybox-1.25.1
	cp -f $< $@

$(WORKDIR)/busybox-1.25.1/busybox: $(WORKDIR)/busybox-1.25.1 $(WORKDIR)/busybox-1.25.1/.config $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc
	cd $(WORKDIR)/busybox-1.25.1 &&	\
	KERNELDIR=$(WORKDIR)/linux-4.9-rc8		\
	KERNELVERSION=4.9-rc8	\
	SRCDIR=$(CODEDIR)		\
	LOCALDIR=$(LOCALDIR)	\
	INITRAMFSDIR=$(INITRAMFSDIR)	\
	make && \
	cd $(BUILD)



$(INITRAMF)/bin/busybox: $(WORKDIR)/busybox-1.25.1/busybox
	cd $(WORKDIR)/busybox-1.25.1 && \
	KERNELDIR=$(WORKDIR)/linux-4.9-rc8		\
	KERNELVERSION=4.9-rc8	\
	SRCDIR=$(CODEDIR)		\
	LOCALDIR=$(LOCALDIR)	\
	INITRAMFSDIR=$(INITRAMFSDIR)	\
	make CONFIG_PREFIX=$(INITRAMFSDIR) install && \
	cd $(BUILD)


# ---- CROSSTOOLS AND CROSSCHAIN -----------------------


$(REPODIR)/crosstool-ng:
	cd $(REPODIR) && \
		git clone https://github.com/crosstool-ng/crosstool-ng &&	\
	cd $(BUILD)


$(REPODIR)/crosstool-ng/ct-ng: $(REPODIR)/crosstool-ng
	cd $(REPODIR)/crosstool-ng && ./bootstrap && \
	./configure --prefix=$(LOCALDIR) &&	MAKELEVEL=0 make && cd $(BUILD)


$(LOCALDIR)/bin/ct-ng: $(REPODIR)/crosstool-ng/ct-ng
	cd $(REPODIR)/crosstool-ng && MAKELEVEL=0 make install && cd $(BUILD)

$(WORKDIR)/crosschain/.config: $(BASE)/extconfigs/crosstools-linux-4.9-rc8
	cd $(WORKDIR)/crosschain && \
	$(LOCALDIR)/bin/ct-ng arm-cortexa9_neon-linux-gnueabihf && \
	cp -f $(BASE)/extconfigs/crosstools-linux-4.9-rc8 $(WORKDIR)/crosschain/.config && \
	cd $(BUILD)


$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc: $(LOCALDIR)/bin/ct-ng $(WORKDIR)/crosschain/.config
	cd $(WORKDIR)/crosschain && \
	KERNELDIR=$(WORKDIR)/linux-4.9-rc8	\
	KERNELVERSION=4.9-rc8	\
	SRCDIR=$(CODEDIR)	\
	LOCALDIR=$(LOCALDIR)	\
	$(LOCALDIR)/bin/ct-ng build && \
	cd $(BUILD)


# ---- POPULATE ----------------------------------------

# $(INITRAMFSDIR)/lib/ld-linux-armhf.so.3: $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/lib



# ---- LINUX KERNEL AND ETC ----------------------------


$(CODEDIR)/linux-4.9-rc8.tar.xz:
	cd $(CODEDIR) && wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-4.9-rc8.tar.xz


$(WORKDIR)/linux-4.9-rc8: $(CODEDIR)/linux-4.9-rc8.tar.xz
	tar -xJvf $< -C $(WORKDIR)


$(WORKDIR)/linux-4.9-rc8/.config: $(BASE)/extconfigs/linux-4.9-rc8
	cp -f $< $@


$(WORKDIR)/linux-4.9-rc8/arch/arm/boot/Image: $(WORKDIR)/linux-4.9-rc8 $(WORKDIR)/linux-4.9-rc8/.config $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH && \
	cd $(WORKDIR)/linux-4.9-rc8 && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules_install INSTALL_MOD_PATH=$(INITRAMFSDIR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make firmware_install  INSTALL_MOD_PATH=$(INITRAMFSDIR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make headers_install INSTALL_HDR_PATH=$(INITRAMFSDIR) && \
	cd $(BUILD)



$(PRODUCTSDIR)/Image: $(WORKDIR)/linux-4.9-rc8/arch/arm/boot/Image
	cp -f $< $@


$(INITRAMFSDIR)/lib/modules/4.9.0-rc8/modules.dep: $(PRODUCTSDIR)/Image



# ---- Initramfs rules ------------------------------------

$(INITRAMFSDIR)/init: $(BASE)/parts/init
	cp -f $< $@


$(PRODUCTSDIR)/initramfs.md5.new:
	@find $(INITRAMFSDIR) | md5sum | awk '{ print $$1 }' > $@

$(PRODUCTSDIR)/initramfs.md5: $(PRODUCTSDIR)/initramfs.md5.new
	@diff $@ $@.new > /dev/null; \
	if [ "z$$?" != "z0" ]; then \
		cp -f $< $@; \
	fi

$(PRODUCTSDIR)/initramfs.igz: $(INITRAMFSDIR)/init $(INITRAMFSDIR)/bin/busybox $(INITRAMFSDIR)/lib/modules/4.9.0-rc8/modules.dep $(INITRAMFSDIR)/lib/ld-linux-armhf.so.3 $(PRODUCTSDIR)/initramfs.md5
	cd $(INITRAMFSDIR) && \
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > $@ && \
	cd $(BUILD)


# ---- Product signing ------------------------------------


$(PRODUCTSDIR)/%.rc4: $(BASE)/parts/%
	openssl rc4 -K $(KEY) < $< > $@

$(PRODUCTSDIR)/unknown.%: $(BASE)/parts/unknown.%
	cp $< $@

$(PRODUCTSDIR)/Image.krn: $(PRODUCTSDIR)/Image $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/Image $@

$(PRODUCTSDIR)/initramfs.igz.krn: $(PRODUCTSDIR)/initramfs.igz $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/initramfs.igz $@

$(PRODUCTSDIR)/parameters.img: $(BASE)/parts/parameters $(RKCRC)
	$(RKCRC) -p $(BASE)/parts/parameters $@

# ---------------------------------------------------------


# ---- We create an SD image of 128 MB and populate it with all the parts
#      Kernel <= 32MB
#      Initramfs <= 128MB

$(OFILESD): $(PRODUCTSDIR)/sd_header.1.rc4 $(PRODUCTSDIR)/sd_header.2.rc4 $(PRODUCTSDIR)/FlashData.bin.rc4 $(PRODUCTSDIR)/FlashBoot.bin.rc4 $(PRODUCTSDIR)/unknown.1 $(PRODUCTSDIR)/unknown.2 $(PRODUCTSDIR)/Image.krn $(PRODUCTSDIR)/initramfs.igz.krn $(PRODUCTSDIR)/parameters.img
	SIZE=`stat -c%%s "$(PRODUCTSDIR)/Image.krn"` && if [ $$SIZE -gt 33554432 ]; then echo "Kernel too big. Adjust parameters file and makefile"; exit 1; fi;
	SIZE=`stat -c%%s "$(PRODUCTSDIR)/initramfs.igz.krn"` && if [ $$SIZE -gt 134217728 ]; then echo "Initramfs too big. Adjust parameters file and makefile."; exit 1; fi;
	dd if=/dev/zero of=$(OFILESD) conv=sync,fsync bs=512 count=262144
	dd if=$(PRODUCTSDIR)/sd_header.1.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=64
	dd if=$(PRODUCTSDIR)/sd_header.2.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=65
	dd if=$(PRODUCTSDIR)/FlashData.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=68
	dd if=$(PRODUCTSDIR)/FlashBoot.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=92
	dd if=$(PRODUCTSDIR)/unknown.1 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8064
	dd if=$(PRODUCTSDIR)/unknown.2 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8065
	dd if=$(PRODUCTSDIR)/Image.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0x4000))
	dd if=$(PRODUCTSDIR)/initramfs.igz.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0x14000))
	dd if=$(PRODUCTSDIR)/parameters.img of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000))




