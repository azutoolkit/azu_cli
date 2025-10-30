PREFIX=/usr/local
INSTALL_DIR=$(PREFIX)/bin
AZU_SYSTEM=$(INSTALL_DIR)/azu

# Manpage installation directories
MANPREFIX=$(PREFIX)/share/man
MANDIR=$(MANPREFIX)/man1

OUT_DIR=$(CURDIR)/bin
AZU=$(OUT_DIR)/azu
SOURCE_FILE=src/azu_cli.cr

all: build | link

build: shard $(AZU)

.PHONY: shard
shard:
	@echo "Building Azu CLI"
	shards build --production --ignore-crystal-version

$(AZU): $(AZU_SOURCES) | $(OUT_DIR)
	crystal build -o $@ $(SOURCE_FILE) -p --no-debug

$(OUT_DIR) $(INSTALL_DIR):
	 @mkdir -p $@

$(MANDIR):
	@mkdir -p $(MANDIR)

.PHONY: run
run:
	$(AZU)

.PHONY: install
install: build | $(INSTALL_DIR)
	rm -f $(AZU_SYSTEM)
	cp $(AZU) $(AZU_SYSTEM)

.PHONY: install-man
install-man: man | $(MANDIR)
	@echo "Installing man page to $(MANDIR)"
	cp docs/man/azu.1 $(MANDIR)/azu.1
	gzip -f $(MANDIR)/azu.1

.PHONY: uninstall-man
uninstall-man:
	@echo "Removing man page from $(MANDIR)"
	rm -f $(MANDIR)/azu.1.gz $(MANDIR)/azu.1

.PHONY: link
link: build | $(INSTALL_DIR)
	@echo "Symlinking $(AZU) to $(AZU_SYSTEM)"
	ln -s $(AZU) $(AZU_SYSTEM)

.PHONY: force_link
force_link: build | $(INSTALL_DIR)
	@echo "Symlinking $(AZU) to $(AZU_SYSTEM)"
	ln -sf $(AZU) $(AZU_SYSTEM)

.PHONY: clean
clean:
	rm -rf $(AZU)

.PHONY: distclean
distclean:
	rm -rf $(AZU) .crystal .shards libs lib

.PHONY: man
man:
	@echo "Man page available at docs/man/azu.1; use 'make install-man' to install"
