PREFIX=/usr/local
INSTALL_DIR=$(PREFIX)/bin
AZU_SYSTEM=$(INSTALL_DIR)/azu

OUT_DIR=$(CURDIR)/bin
AZU=$(OUT_DIR)/azu
SOURCE_FILE=src/azu_cli.cr

all: build

build: shard $(AZU)

shard:
	@echo "Building Azu CLI"
	@shards build --production --ignore-crystal-version

$(AZU): $(AZU_SOURCES) | $(OUT_DIR)
	@crystal build -o $@ $(SOURCE_FILE) -p --no-debug

$(OUT_DIR) $(INSTALL_DIR):
	 @mkdir -p $@

run:
	$(AZU)

install: build | $(INSTALL_DIR)
	@rm -f $(AZU_SYSTEM)
	@cp $(AZU) $(AZU_SYSTEM)

link: build | $(INSTALL_DIR)
	@echo "Symlinking $(AZU) to $(AZU_SYSTEM)"
	@ln -s $(AZU) $(AZU_SYSTEM)

force_link: build | $(INSTALL_DIR)
	@echo "Symlinking $(AZU) to $(AZU_SYSTEM)"
	@ln -sf $(AZU) $(AZU_SYSTEM)

clean:
	rm -rf $(AZU)

distclean:
	rm -rf $(AZU) .crystal .shards libs lib