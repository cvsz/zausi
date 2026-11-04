SHELL := /bin/sh

# --- OpenCode CLI configuration (override on the command line or in .env) ---
OPENCODE_BIN ?= opencode
# Model for make opencode-prompt / make opencode-bg (provider/model form).
OPENCODE_MODEL ?=
# 100% free model used by the *-free-* targets (OpenCode Zen free tier).
OPENCODE_FREE_MODEL ?= opencode/ilm-model-lite
# Non-interactive permission auto-answers: ask | allow | deny
OPENCODE_AUTO_APPROVE ?= deny
# Directory (relative to repo root) holding provider catalog scripts.
MODEL_CATALOG_DIR ?= model-catalog

.PHONY: help validate-template setup format lint test build security ci \
	opencode opencode-prompt opencode-free-prompt opencode-bg opencode-free-bg \
	opencode-models opencode-free-models opencode-nvidia-models opencode-kilo-models

help:
	@printf '%s\n' 'Targets:' \
		'  make validate-template - Run repository structure and link validation' \
		'  make test              - Run python unit tests' \
		'  make lint              - Run python syntax and structure checks' \
		'  make build             - Run compilation check on scripts' \
		'  make security          - Run security and validation checks' \
		'  make ci                - Run full CI validation suite' \
		'' \
		'OpenCode CLI:' \
		'  make opencode                 - Run OpenCode TUI (.env auto-loaded)' \
		'  make opencode-prompt PROMPT="..." [OPENCODE_MODEL="..."]' \
		'                                - Run a prompt via OpenCode (foreground)' \
		'  make opencode-free-prompt PROMPT="..."' \
		'                                - Run a prompt using the 100% free model' \
		'  make opencode-bg PROMPT="..."         - Run an OpenCode prompt in background' \
		'  make opencode-free-bg PROMPT="..."    - Run free-model prompt in background' \
		'' \
		'Model listings:' \
		'  make opencode-models        - List all available OpenCode models' \
		'  make opencode-free-models   - List free models (NVIDIA, OpenCode, Kilo, etc.)' \
		'  make opencode-nvidia-models - List NVIDIA Nemotron & NIM models' \
		'  make opencode-kilo-models   - List Kilo models & free routers' \
		'' \
		'Background runs: logs under .tmp/opencode/<run-id>.log;' \
		'  make opencode-bg-status [RUN_ID=x] / make opencode-bg-tail RUN_ID=x [N=50]' \
		'  make opencode-bg-list'

validate-template:
	python3 scripts/validate_repo.py
	python3 -m unittest discover -s tests -v

format:
	python3 -m py_compile scripts/*.py tests/*.py

lint:
	python3 -m py_compile scripts/*.py tests/*.py
	python3 scripts/validate_repo.py

test:
	python3 -m unittest discover -s tests -v

build:
	python3 -m py_compile scripts/*.py

security:
	python3 scripts/validate_repo.py

ci: validate-template lint test build security

# ---------------------------------------------------------------------------
# OpenCode CLI targets
#
# .env auto-loading: each recipe loads ./.env via scripts/opencode_env.py and
# exports the variables to child processes (values are never echoed). Never
# commit real credentials; see .env.example. OPENCODE_AUTO_APPROVE defaults to
# `deny` so non-interactive runs cannot mutate the workspace without review.
ENVLOAD = eval "$$(python3 scripts/opencode_env.py)"; export $$(cut -d= -f1 ./.env 2>/dev/null | grep -E '^[A-Za-z_][A-Za-z0-9_]*$$' || true)

opencode:
	@$(ENVLOAD); \
	command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH. Install: curl -fsSL https://opencode.ai/install | bash" >&2; exit 127; }; \
	exec $(OPENCODE_BIN)

opencode-prompt:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-prompt PROMPT=\"...\" [OPENCODE_MODEL=\"provider/model\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
	if [ -n "$(OPENCODE_MODEL)" ]; then \
		$(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE); \
	else \
		$(OPENCODE_BIN) run "$(PROMPT)" --auto-approve $(OPENCODE_AUTO_APPROVE); \
	fi

opencode-free-prompt:
	@$(MAKE) --no-print-directory opencode-prompt PROMPT="$(PROMPT)" OPENCODE_MODEL="$(OPENCODE_FREE_MODEL)"

opencode-bg:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-bg PROMPT=\"...\" [OPENCODE_MODEL=\"provider/model\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
	if [ -n "$(OPENCODE_MODEL)" ]; then \
		python3 scripts/opencode_bg.py run -- $(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE); \
	else \
		python3 scripts/opencode_bg.py run -- $(OPENCODE_BIN) run "$(PROMPT)" --auto-approve $(OPENCODE_AUTO_APPROVE); \
	fi

opencode-free-bg:
	@$(MAKE) --no-print-directory opencode-bg PROMPT="$(PROMPT)" OPENCODE_MODEL="$(OPENCODE_FREE_MODEL)"

opencode-bg-status:
	@python3 scripts/opencode_bg.py status $(RUN_ID)

opencode-bg-list:
	@python3 scripts/opencode_bg.py list

opencode-bg-tail:
	@if [ -z "$(RUN_ID)" ]; then echo "usage: make opencode-bg-tail RUN_ID=<id> [N=50]" >&2; exit 2; fi
	@python3 scripts/opencode_bg.py tail "$(RUN_ID)" $(or $(N),50)

# ---------------------------------------------------------------------------
# Model listing targets
#
# Resolution order per provider: repo-local catalog script
# (model-catalog/list-<name>.sh|.py, if present) -> generic `opencode models`
# filtered by substring. Catalog scripts are the place to encode provider
# specifics (e.g. NVIDIA NIM's OpenAI-compatible endpoint at
# https://integrate.api.nvidia.com/v1, or Kilo Code free router aliases).
# ---------------------------------------------------------------------------

opencode-models:
	@$(ENVLOAD); \
	command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
	$(OPENCODE_BIN) models

opencode-free-models:
	@found=0; \
	for s in $(MODEL_CATALOG_DIR)/list-free.sh $(MODEL_CATALOG_DIR)/list-free.py; do \
		if [ -f "$$s" ]; then found=1; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# Free models (substring filter on '$(OPENCODE_BIN) models'; edit $(MODEL_CATALOG_DIR)/list-free.* for curated lists)"; \
		$(MAKE) --no-print-directory opencode-models | grep -Ei 'free|lite|nemotron|kilo|zen' || echo "(none matched — verify provider credentials in .env)"; \
	fi

opencode-nvidia-models:
	@found=0; \
	for s in $(MODEL_CATALOG_DIR)/list-nvidia.sh $(MODEL_CATALOG_DIR)/list-nvidia.py; do \
		if [ -f "$$s" ]; then found=1; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# NVIDIA Nemotron & NIM models (substring filter; requires NVIDIA catalogue access)"; \
		echo "# Tip: NVIDIA NIM is OpenAI-compatible — set NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1 and an NIM catalog script in $(MODEL_CATALOG_DIR)/."; \
		$(MAKE) --no-print-directory opencode-models | grep -Ei 'nvidia|nemotron' || echo "(none matched — configure the nvidia provider, e.g. nvapi- key via 'opencode auth login')"; \
	fi

opencode-kilo-models:
	@found=0; \
	for s in $(MODEL_CATALOG_DIR)/list-kilo.sh $(MODEL_CATALOG_DIR)/list-kilo.py; do \
		if [ -f "$$s" ]; then found=1; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# Kilo models & free routers (substring filter)"; \
		$(MAKE) --no-print-directory opencode-models | grep -Ei 'kilo' || echo "(none matched — install/configure the kilo provider gateway)"; \
	fi
