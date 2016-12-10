

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



.PHONY: $(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(PRODUCTSDIR)/initramfs.md5.new


all: $(OFILENAND)
	@echo "fin"


$(REPODIR) $(CODEDIR) $(PRODUCTSDIR) $(LOCALDIR) $(INITRAMFSDIR) $(WORKDIR)/crosschain:
	mkdir -p $@


$(REPODIR)/rkflashtool: $(REPODIR)
	cd $(REPODIR) && \
		git clone https://github.com/durandmiller/rkflashtool.git &&	\
	cd $(BUILD)


$(RKCRC): $(REPODIR)/rkflashtool
	$(MAKE) -C $(REPODIR)/rkflashtool/


# ------------------------------------------------------

#prep directories
#download sources
#clone 3 repos
#build rkflashtool
#build crosstools (TOOL)
#extract kernel
#build crosschain (CHAIN)
#build busybox
#install busybox
#populate crosschain
#build kernel


# ------------------------------------------------------



$(REPODIR)/crosstool-ng:
	cd $(REPODIR) && \
		git clone https://github.com/crosstool-ng/crosstool-ng &&	\
	cd $(BUILD)


$(REPODIR)/crosstool-ng/ct-ng:
	cd $(REPODIR)/crosstool-ng && ./bootstrap && \
	./configure --prefix=$(LOCALDIR) &&	make && cd $(BUILD)


$(LOCALDIR)/bin/ct-ng: $(REPODIR)/crosstool-ng $(REPODIR)/crosstool-ng/ct-ng
	cd $(REPODIR)/crosstool-ng && make install

$(WORKDIR)/crosschain/.config: $(WORKDIR)/crosschain $(BASE)/extconfig/crosstools-linux-4.9-rc8
	cd $(WORKDIR)/crosschain && \
	$(LOCALDIR)/bin/ct-ng arm-cortexa9_neon-linux-gnueabihf && \
	cp -f $(BASE)/extconfigs/crosstools-linux-4.9-rc8 $(WORKDIR)/crosschain/.config


$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc: $(LOCALDIR) $(LOCALDIR)/bin/ct-ng $(WORKDIR)/crosschain/.config
	cd $(WORKDIR)/crosschain && \
	KERNELDIR=$(WORKDIR)/linux-4.9-rc8	\
	KERNELVERSION=$(WORKDIR)/4.9-rc8	\
	SRCDIR=$(CODEDIR)	\
	LOCALDIR=$(LOCALDIR)	\
	$(LOCALDIR)/bin/ct-ng build && \
	cd $(BASE)



$(CODEDIR)/linux-4.9-rc8.tar.xz:
	cd $(CODEDIR) && wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-4.9-rc8.tar.xz


$(WORKDIR)/linux-4.9-rc8: $(CODEDIR)/linux-4.9-rc8.tar.xz
	tar -xJvf $< -C $(WORKDIR)


$(WORKDIR)/linux-4.9-rc8/.config: $(BASE)/extconfigs/linux-4.9-rc8
	cp -f $< $@


$(CODEDIR)/linux-4.9-rc8/arch/arm/boot/Image: $(WORKDIR)/linux-4.9-rc8 $(WORKDIR)/linux-4.9-rc8/.config $(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/arm-cortexa9_neon-linux-gnueabihf-gcc
	PATH=$(LOCALDIR)/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin/:$$PATH && \
	cd $(WORKDIR)/linux-4.9-rc8 && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make modules_install INSTALL_MOD_PATH=$(INITRAMFSDIR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make firmware_install  INSTALL_MOD_PATH=$(INITRAMFSDIR) && \
	ARCH="arm" CROSS_COMPILE="arm-cortexa9_neon-linux-gnueabihf-" make headers_install INSTALL_HDR_PATH=$(INITRAMFSDIR) && \
	cd $(BUILD)



$(PRODUCTSDIR)/Image: $(CODEDIR)/linux-4.9-rc8/arch/arm/boot/Image
	cp -f $< $@



$(INITRAMFSDIR)/init: $(BASE)/parts/init
	cp -f $< $@


$(PRODUCTSDIR)/initramfs.md5.new:
	@find $(INITRAMFSDIR) | md5sum | awk '{ print $$1 }' > $@

$(PRODUCTSDIR)/initramfs.md5: $(PRODUCTSDIR)/initramfs.md5.new
	@diff $@ $@.new > /dev/null; \
	if [ "z$$?" != "z0" ]; then \
		cp -f $< $@; \
	fi

$(PRODUCTSDIR)/initramfs.igz: $(INITRAMFSDIR)/init $(PRODUCTSDIR)/initramfs.md5
	cd $(INITRAMFSDIR) && \
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > $@ && \
	cd $(BUILD)


$(PRODUCTSDIR)/%.rc4: $(BASE)/parts/%
	openssl rc4 -K $(KEY) < $< > $@

$(PRODUCTSDIR)/unknown.%: $(BASE)/parts/unknown.%
	cp $< $@

$(PRODUCTSDIR)/Image.krn: $(PRODUCTSDIR)/Image $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/Image $@

$(PRODUCTSDIR)/initramfs.igz.krn: $(PRODUCTSDIR)/initramfs.igz $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/initramfs.igz $@

$(PRODUCTSDIR)/paramaters.img: $(BASE)/parts/parameters $(RKCRC)
	$(RKCRC) -p $(BASE)/parts/parameters $@


$(OFILESD): $(PRODUCTSDIR)/sd_header.1.rc4 $(PRODUCTSDIR)/sd_header.2.rc4 $(PRODUCTSDIR)/FlashData.bin.rc4 $(PRODUCTSDIR)/FlashBoot.bin.rc4 $(PRODUCTSDIR)/unknown.1 $(PRODUCTSDIR)/unknown.2 $(PRODUCTSDIR)/Image.krn $(PRODUCTSDIR)/initramfs.igz.krn $(PRODUCTSDIR)/parameters.img
	dd if=/dev/zero of=$(OFILESD) conv=sync,fsync bs=512 count=8192
	dd if=$(PRODUCTSDIR)/sd_header.1.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=64
	dd if=$(PRODUCTSDIR)/sd_header.2.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=65
	dd if=$(PRODUCTSDIR)/FlashData.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=68
	dd if=$(PRODUCTSDIR)/FlashBoot.bin.rc4 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=92
	dd if=$(PRODUCTSDIR)/unknown.1 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8064
	dd if=$(PRODUCTSDIR)/unknown.2 of=$(OFILESD) conv=notrunc,sync,fsync bs=512 seek=8065
	dd if=$(PRODUCTSDIR)/Image.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0x4000))
	dd if=$(PRODUCTSDIR)/initramfs.igz.krn of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000 + 0xC000))
	dd if=$(PRODUCTSDIR)/parameters.img of=$(OFILESD) conv=notrunc,sync,fsync seek=$$((0x2000))


$(OFILENAND): $(OFILESD)
	cp $(OFILESD) $(OFILENAND)
	dd if=$(PRODUCTSDIR)/parameters.img of=$(OFILENAND) conv=notrunc,sync,fsync seek=$$((0x0000))



