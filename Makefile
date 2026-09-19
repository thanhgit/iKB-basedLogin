.PHONY: run install uninstall

run:
	sh -c ./unlock.sh
	
PREFIX       := /opt/ai-secure-shell
BIN_DIR      := /usr/local/bin
BIN          := $(BIN_DIR)/ai-secure-shell
STATE_DIR    := /var/lib/ai-secure-shell
ORIGINAL     := $(STATE_DIR)/original-shell

USER         ?= aiagent
SHELL_PATH   := /bin/bash


install:
	@set -e; \
	echo "==> Installing ai-secure-shell for user '$(USER)'"; \
	\
	if ! id "$(USER)" >/dev/null 2>&1; then \
		echo "ERROR: user '$(USER)' does not exist"; \
		exit 1; \
	fi; \
	\
	if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: please run: sudo make install"; \
		exit 1; \
	fi; \
	\
	mkdir -p "$(PREFIX)" "$(STATE_DIR)"; \
	\
	CURRENT_SHELL="$$(getent passwd "$(USER)" | cut -d: -f7)"; \
	if [ ! -f "$(ORIGINAL)" ]; then \
		echo "$$CURRENT_SHELL" > "$(ORIGINAL)"; \
		echo "==> Saved original shell: $$CURRENT_SHELL"; \
	fi; \
	\
	install -m 755 unlock.sh "$(PREFIX)/unlock.sh"; \
	install -m 644 config.json "$(PREFIX)/config.json"; \
	install -m 644 questions.json "$(PREFIX)/questions.json"; \
	\
	printf '%s\n' \
		'#!/usr/bin/env bash' \
		'set -euo pipefail' \
		'' \
		'BASE_DIR="$(PREFIX)"' \
		'' \
		'if ! "$$BASE_DIR/unlock.sh"; then' \
		'    exit 1' \
		'fi' \
		'' \
		'exec /bin/bash -l' \
		> "$(BIN)"; \
	\
	chmod 755 "$(BIN)"; \
	\
	chsh -s "$(BIN)" "$(USER)"; \
	\
	echo ""; \
	echo "✓ Installed successfully."; \
	echo "  User:       $(USER)"; \
	echo "  Login shell: $(BIN)"; \
	echo ""

uninstall:
	@set -e; \
	echo "==> Uninstalling ai-secure-shell"; \
	\
	if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: please run: sudo make uninstall"; \
		exit 1; \
	fi; \
	\
	if id "$(USER)" >/dev/null 2>&1; then \
		if [ -f "$(ORIGINAL)" ]; then \
			ORIGINAL_SHELL="$$(cat "$(ORIGINAL)")"; \
			echo "==> Restoring shell: $$ORIGINAL_SHELL"; \
			chsh -s "$$ORIGINAL_SHELL" "$(USER)"; \
		else \
			echo "WARNING: original shell not found."; \
			echo "         User shell was not changed."; \
		fi; \
	fi; \
	\
	rm -f "$(BIN)"; \
	rm -rf "$(PREFIX)"; \
	rm -rf "$(STATE_DIR)"; \
	\
	echo ""; \
	echo "✓ Uninstalled successfully."; \
	echo ""

	