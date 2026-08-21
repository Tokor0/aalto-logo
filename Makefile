# Glue over the logo pipeline and the package layout. The Python targets need
# `nix develop` (or python3 + Pillow + mutool on PATH); the rest need only
# typst and coreutils.

VERSION := $(shell sed -n 's/^version *= *"\(.*\)"/\1/p' typst.toml)
NAME    := $(shell sed -n 's/^name *= *"\(.*\)"/\1/p' typst.toml)

DATA_HOME := $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)
PKG_DIR   := $(DATA_HOME)/typst/packages/local/$(NAME)/$(VERSION)

# Every test imports ../lib.typ, so the project root has to be the repo, not
# tests/ -- otherwise Typst refuses the path as escaping the sandbox.
TYPST  := typst compile --root .
TESTS  := $(wildcard tests/*.typ)
BUILD  := build

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "$(NAME) $(VERSION)"
	@echo
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| sed 's/:.*## /\t/' \
		| awk -F'\t' '{ printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }'

.PHONY: sources
sources: ## Download the logo PDFs and reference PNGs into sources/
	python3 download_logos.py --format both

.PHONY: logos
logos: ## Regenerate logos/*.typ from sources/pdf (needs mutool)
	python3 build_vectors.py

.PHONY: test
test: $(BUILD) ## Compile every test document
	@for t in $(TESTS); do \
		echo "  typst $$t"; \
		$(TYPST) "$$t" "$(BUILD)/$$(basename $$t .typ).pdf" || exit 1; \
	done
	@echo "OK -- $(words $(TESTS)) documents compiled into $(BUILD)/"

.PHONY: compare
compare: ## Pixel-diff the curve data against the reference PNGs
	python3 tests/compare_render.py

.PHONY: example
example: ## Render the README illustration
	$(TYPST) --format png --ppi 200 docs/example.typ docs/example.png

.PHONY: install-local
install-local: ## Symlink this repo into the local Typst package dir
	@mkdir -p "$(dir $(PKG_DIR))"
	@rm -rf "$(PKG_DIR)"
	@ln -s "$(CURDIR)" "$(PKG_DIR)"
	@echo "linked $(PKG_DIR) -> $(CURDIR)"
	@echo 'import it with:  #import "@local/$(NAME):$(VERSION)": aalto-logo'

.PHONY: uninstall-local
uninstall-local: ## Remove the @local symlink
	@rm -rf "$(PKG_DIR)"
	@echo "removed $(PKG_DIR)"

# Stages what `typst.toml`'s exclude list would leave in the published bundle,
# so you can look at it before submitting. VCS files are dropped too; Universe
# takes the bundle from a directory in its own repo, not from this checkout.
.PHONY: pack
pack: ## Stage the publishable bundle into dist/
	@rm -rf dist && mkdir -p dist
	@excludes=$$(sed -n '/^exclude *= *\[/,/^]/p' typst.toml \
		| sed -n 's/^ *"\(.*\)",\?$$/\1/p' \
		| sed 's|^/|./|' \
		| while read -r p; do printf ' --exclude=%s' "$$p"; done); \
	tar -cf - --exclude-vcs --exclude=./dist --exclude=./.claude $$excludes . \
		| tar -xf - -C dist
	@echo
	@find dist -type f | sort | sed 's|^dist/||' | head -8
	@echo "  ... $$(find dist -type f | wc -l) files, $$(du -sh dist | cut -f1) total"

$(BUILD):
	@mkdir -p $(BUILD)

.PHONY: clean
clean: ## Remove build output
	rm -rf $(BUILD) dist
