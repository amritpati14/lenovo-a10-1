
BASE=/home/durand/projects/public/lenovo-a10
BUILD=/home/durand/temp/lenovoa10

PRODUCTSDIR=$(BUILD)/products
INITRAMFSDIR=$(BUILD)/initramfs
REPODIR=$(BUILD)/src/repos
SRCDIR=$(BUILD)/src/code

RKCRC=$(REPODIR)/rkflashtool/rkcrc


KEY=7C4E0304550509072D2C7B38170D1711




OFILESD=$(PRODUCTSDIR)/rk3188_sdboot.img
OFILENAND=$(PRODUCTSDIR)/rk3188_nand.img


all: $(OFILENAND)
	@echo "fin"

$(RKCRC):
	$(MAKE) -C $(REPODIR)/rkflashtool/


$(PRODUCTSDIR)/initramfs.igz:
	cd $(INITRAMFSDIR) && \
	find . | cpio -H newc -R +0:+0 -o | gzip -9 > $(PRODUCTSDIR)/initramfs.igz && \
	cd $(BUILD)


$(PRODUCTSDIR)/%.rc4: $(BASE)/parts/%
	openssl rc4 -K $(KEY) < $< > $@

$(PRODUCTSDIR)/unknown.%: $(BASE)/parts/unknown.%
	cp $< $@

$(PRODUCTSDIR)/Image.krn: $(PRODUCTSDIR)/Image $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/Image $(PRODUCTSDIR)/Image.krn

$(PRODUCTSDIR)/initramfs.igz.krn: $(PRODUCTSDIR)/initramfs.igz $(RKCRC)
	$(RKCRC) -k $(PRODUCTSDIR)/initramfs.igz $(PRODUCTSDIR)/initramfs.igz.krn

$(PRODUCTSDIR)/paramaters.img: $(BASE)/parts/parameters $(RKCRC)
	$(RKCRC) -p $(BASE)/parts/parameters $(PRODUCTSDIR)/parameters.img


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



