PREFIX=$$HOME/.local
INSTALL_DIR=$(PREFIX)/bin
AZU_SYSTEM=$(INSTALL_DIR)/azu

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

.PHONY: run
run:
	$(AZU)

.PHONY: install
install: build | $(INSTALL_DIR)
	rm -f $(AZU_SYSTEM)
	cp $(AZU) $(AZU_SYSTEM)

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