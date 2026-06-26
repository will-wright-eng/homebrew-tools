#* Setup
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))
.DEFAULT_GOAL := help

TAP_NAME   := will-wright-eng/tools
TAP_DIR    := $(shell brew --repository 2>/dev/null)/Library/Taps/will-wright-eng/homebrew-tools
FORMULAS   := hc mgmt
QUALIFIED  := $(addprefix $(TAP_NAME)/,$(FORMULAS))
HC_VERSION := 1.3.0

help: ## list make commands
	@echo "Root commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

#* Tap

tap: ## symlink this repo into Homebrew as the will-wright-eng/tools tap
	@mkdir -p "$(dir $(TAP_DIR))"
	@if [ ! -L "$(TAP_DIR)" ]; then rm -rf "$(TAP_DIR)"; ln -sfn "$(CURDIR)" "$(TAP_DIR)"; fi
	@echo "tapped $(TAP_NAME) -> $(CURDIR)"

untap: ## remove the local tap
	@if [ -L "$(TAP_DIR)" ]; then rm -f "$(TAP_DIR)"; else brew untap $(TAP_NAME) >/dev/null 2>&1 || true; fi
	@echo "untapped $(TAP_NAME)"

#* Checks

style: tap ## lint formula style (rubocop via brew)
	brew style $(QUALIFIED)

audit: tap ## run strict formula audit
	brew audit --strict $(QUALIFIED)

livecheck: tap ## report whether newer upstream versions exist
	brew livecheck --newer-only $(QUALIFIED)

check: ## full local pipeline: style, audit, install, test
	@$(MAKE) style
	@$(MAKE) audit
	@$(MAKE) install
	@$(MAKE) test

#* Lifecycle

install: tap ## install both formulas from the local tap
	brew install $(QUALIFIED)

reinstall: tap ## force reinstall both formulas
	brew reinstall $(QUALIFIED)

uninstall: ## uninstall both formulas
	-brew uninstall $(QUALIFIED)

test: tap ## run each formula's test block
	brew test $(QUALIFIED)

resources: tap ## regenerate mgmt python resource blocks
	brew update-python-resources $(TAP_NAME)/mgmt

#* Maintenance

info: tap ## show formula metadata
	brew info $(QUALIFIED)

checksums: ## print upstream hc release checksums (for version bumps)
	@curl -sL https://github.com/will-wright-eng/hc/releases/download/v$(HC_VERSION)/checksums.txt

clean: uninstall untap ## uninstall formulas and remove the tap link
	@echo "cleaned"
