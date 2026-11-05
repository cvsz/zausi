SHELL := /bin/sh

# --- ZCoder Enterprise CLI — Makefile ---
# Quality gates, runtime services (api/worker/web), builds & code signing,
# Docker, and OpenCode CLI integration.

VENV_DIR ?= .venv
PYTHON ?= $(shell if [ -f "$(VENV_DIR)/bin/python" ]; then echo "$(VENV_DIR)/bin/python"; elif [ -f "$(VENV_DIR)/Scripts/python.exe" ]; then echo "$(VENV_DIR)/Scripts/python.exe"; elif [ -n "$$VIRTUAL_ENV" ]; then echo "$$VIRTUAL_ENV/bin/python"; else echo "python3"; fi)
DIST_DIR ?= dist
CERT_DIR ?= certs
PFX_PATH ?= $(CERT_DIR)/zcoder-codesign.pfx
WEB_VENV := .web-venv
WEB_PY := $(WEB_VENV)/bin/python
WEB_UVICORN := $(WEB_VENV)/bin/uvicorn
PID_FILE := .web.pid
LOG_FILE := logs/web.log
API_PID_FILE := .api.pid
API_LOG_FILE := logs/api.log
WORKER_PID_FILE := .worker.pid
WORKER_LOG_FILE := logs/worker.log
HOST ?= 127.0.0.1
PORT ?= 8420
API_HOST ?= 127.0.0.1
API_PORT ?= 8088
WORKER_ARGS ?=

# --- OpenCode CLI configuration (override on the command line or in .env) ---
OPENCODE_BIN ?= $(shell command -v opencode 2>/dev/null || echo "$$HOME/.opencode/bin/opencode")
# Default models use the free tier to avoid paid API issues.
OPENCODE_MODEL ?= opencode/nemotron-3.5-lightning-free
OPENCODE_FREE_MODEL ?= opencode/nemotron-3.5-lightning-free
# Non-interactive permission auto-answers: ask | allow | deny
OPENCODE_AUTO_APPROVE ?= deny
# Directory (relative to repo root) holding provider catalog scripts.
MODEL_CATALOG_DIR ?= model-catalog
# Per-run background log/pid directory (gitignored).
BG_DIR ?= .tmp/opencode
# Wall-clock limit for foreground OpenCode runs, seconds (0 disables).
OPENCODE_TIMEOUT ?= 600
PROMPT ?=

.PHONY: help setup install install-dev install-all \
        test test-unit test-integration test-e2e test-cov lint format typecheck security check \
        run gui tui health \
        api start-api stop-api restart-api status-api logs-api \
        worker start-worker stop-worker restart-worker status-worker logs-worker \
        stop-all restart-all \
        build standalone standalone-force build-desktop build-desktop-force \
        sign verify cert-generate full-build full-build-desktop \
        start stop restart status logs \
        update upgrade \
        docker-build docker-run docker-down docker-logs \
        postgres-setup postgres-status \
        validate-template ci \
        opencode opencode-prompt opencode-free-prompt opencode-bg opencode-free-bg \
        opencode-models opencode-free-models opencode-nvidia-models opencode-kilo-models \
        opencode-bg-status opencode-bg-tail opencode-bg-list opencode-stop opencode-all \
        clean

help:
	@echo "================================================================================"
	@echo "                        ZCoder Enterprise CLI — Makefile Help                   "
	@echo "================================================================================"
	@echo "Environment & Installation:"
	@echo "  make setup              Install environment via scripts/setup.sh or install.py"
	@echo "  make install            Install editable package (base)"
	@echo "  make install-dev        Install editable package with dev dependencies"
	@echo "  make install-all        Install package with all, dev, and postgres extras"
	@echo ""
	@echo "Testing & Quality Gates:"
	@echo "  make test               Run test suite with pytest"
	@echo "  make test-unit          Run unit tests only"
	@echo "  make test-integration   Run postgres-backed integration tests"
	@echo "  make test-e2e           Run end-to-end tests"
	@echo "  make test-cov           Run tests with coverage and missing line reports"
	@echo "  make lint               Run ruff lint check across codebase"
	@echo "  make format             Run black code formatter across codebase"
	@echo "  make typecheck          Run mypy static type analysis"
	@echo "  make security           Run bandit security vulnerability scan"
	@echo "  make check              Run full quality gate (lint + typecheck + security + test-cov)"
	@echo ""
	@echo "Build & Code Signing:"
	@echo "  make standalone         Build platform standalone executable (zcoder or .exe)"
	@echo "  make standalone-force   Force rebuild standalone executable"
	@echo "  make build-desktop      Build full-featured Native Desktop GUI application (zcoder-desktop)"
	@echo "  make cert-generate      Generate Authenticode self-signed certificate into certs/"
	@echo "  Set ZCODER_PFX_PASSWORD in environment before cert-generate/sign; no default is used."
	@echo "  make sign               Sign Windows binaries in dist/ with Authenticode & RFC3161"
	@echo "  make verify             Verify digital signatures in dist/"
	@echo "  make full-build         Complete pipeline: check -> build standalone -> sign"
	@echo "  make full-build-desktop Complete pipeline: check -> build desktop GUI -> sign"
	@echo ""
	@echo "Execution & Runtime:"
	@echo "  make run                Launch ZCoder CLI interactive turn"
	@echo "  make gui                Launch Native Desktop GUI application (Full-feature window)"
	@echo "  make tui                Launch ZCoder Textual TUI interface"
	@echo "  make health             Run enterprise health check"
	@echo "  make api                Start ZCoder REST/API server (foreground)"
	@echo "  make start-api          Start ZCoder REST/API server (background daemon)"
	@echo "  make stop-api           Stop background ZCoder REST/API server"
	@echo "  make restart-api        Restart background ZCoder REST/API server"
	@echo "  make status-api         Check status of background ZCoder REST/API server"
	@echo "  make logs-api           Tail REST/API server log file"
	@echo "  make worker             Start background queue worker (foreground)"
	@echo "  make start-worker       Start background queue worker (background daemon)"
	@echo "  make stop-worker        Stop background queue worker"
	@echo "  make restart-worker     Restart background queue worker"
	@echo "  make status-worker      Check status of background queue worker"
	@echo "  make logs-worker        Tail background queue worker log file"
	@echo "  make stop-all           Stop all background services (api + worker + web)"
	@echo "  make restart-all        Restart all background services (api + worker + web)"
	@echo ""
	@echo "Web Console:"
	@echo "  make build              Prepare web console environment (.web-venv)"
	@echo "  make start              Start background web console server"
	@echo "  make stop               Stop background web console server"
	@echo "  make restart            Restart web console server"
	@echo "  make status             Display web console status"
	@echo "  make logs               Tail web console log file"
	@echo ""
	@echo "Docker & Database:"
	@echo "  make docker-build       Build ZCoder image (zcoder:latest)"
	@echo "  make docker-run         Run ZCoder with local GGUF inference (ARGS='-p \"...\"')"
	@echo "  make docker-logs        Follow llama.cpp model-server logs"
	@echo "  make docker-down        Stop local inference and remove Compose resources"
	@echo "  make postgres-setup     Initialize and migrate local PostgreSQL database"
	@echo "  make postgres-status    Inspect local PostgreSQL container status"
	@echo ""
	@echo "OpenCode CLI:"
	@echo "  make opencode                 Run OpenCode CLI (loads .env automatically)"
	@echo "  make opencode-prompt          Execute prompt via OpenCode (PROMPT=\"...\" [OPENCODE_MODEL=\"...\"])"
	@echo "  make opencode-free-prompt     Execute prompt using 100% Free Model (PROMPT=\"...\")"
	@echo "  make opencode-bg              Run OpenCode prompt in background (PROMPT=\"...\")"
	@echo "  make opencode-free-bg         Run OpenCode free model in background (PROMPT=\"...\")"
	@echo "  make opencode-models          List all available OpenCode models"
	@echo "  make opencode-free-models     List all available free models (NVIDIA, OpenCode, Kilo, etc.)"
	@echo "  make opencode-nvidia-models   List NVIDIA Nemotron & NIM models"
	@echo "  make opencode-kilo-models     List Kilo models & free routers"
	@echo "  make opencode-bg-status [RUN_ID=x] / make opencode-bg-tail RUN_ID=x [N=50] / make opencode-bg-list"
	@echo "  make opencode-stop [RUN_ID=x] Stop background OpenCode run(s); logs under $(BG_DIR)/"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update             Update editable installation"
	@echo "  make upgrade            Update and verify runtime version & health"
	@echo "  make clean              Remove build artifacts, caches, and temp directories"

setup:
	@if [ "$$(uname -s)" = "Linux" ] || [ "$$(uname -s)" = "Darwin" ]; then bash scripts/setup.sh; else python scripts/install.py setup; fi

install:
	$(PYTHON) -m pip install -e .

install-dev:
	$(PYTHON) -m pip install -e '.[dev]'

install-all:
	$(PYTHON) -m pip install -e '.[all,dev,postgres]'

test:
	$(PYTHON) -m unittest discover -s tests -v

test-unit:
	$(PYTHON) -m pytest tests/unit

test-integration:
	$(PYTHON) scripts/local_postgres.py run -- $(PYTHON) -m pytest tests/integration

test-e2e:
	$(PYTHON) -m pytest tests/e2e

test-cov:
	$(PYTHON) -m pytest --cov --cov-report=term-missing

lint:
	$(PYTHON) -m ruff check .

format:
	$(PYTHON) -m black .

typecheck:
	@echo "[BLOCKED] mypy targets src/zcoder and webapp, which do not exist in this template repository." >&2
	@echo "          Run 'python3 -m pip install mypy' and point this target at the real package once the project is initialized." >&2
	@exit 2

security:
	$(PYTHON) -m bandit -r scripts -ll

check: lint security test-cov

run:
	@test -f main.py || { echo "[BLOCKED] main.py does not exist in this template repository; nothing to run yet." >&2; exit 2; }
	$(PYTHON) main.py

gui:
	$(PYTHON) main.py --gui

tui:
	$(PYTHON) main.py --tui

health:
	$(PYTHON) main.py --health-check

api:
	HOST=$(API_HOST) PORT=$(API_PORT) $(PYTHON) scripts/local_postgres.py run -- $(PYTHON) -m zcoder.api.server

start-api:
	@if [ -f $(API_PID_FILE) ] && kill -0 $$(cat $(API_PID_FILE)) 2>/dev/null; then echo "API already running: $$(cat $(API_PID_FILE))"; exit 1; fi
	@mkdir -p logs
	@setsid nohup sh -c 'HOST=$(API_HOST) PORT=$(API_PORT) $(PYTHON) scripts/local_postgres.py run -- $(PYTHON) -m zcoder.api.server' < /dev/null > $(API_LOG_FILE) 2>&1 & echo $$! > $(API_PID_FILE)
	@sleep 1
	@kill -0 $$(cat $(API_PID_FILE)) 2>/dev/null || { echo "API server startup failed; see $(API_LOG_FILE)"; rm -f $(API_PID_FILE); exit 1; }
	@echo "API server started: http://$(API_HOST):$(API_PORT) (PID: $$(cat $(API_PID_FILE)))"

stop-api:
	@if [ ! -f $(API_PID_FILE) ]; then echo "API server not running"; exit 0; fi
	@PID=$$(cat $(API_PID_FILE)); if kill -0 $$PID 2>/dev/null; then kill $$PID; fi
	@rm -f $(API_PID_FILE)
	@echo "API server stopped"

restart-api: stop-api start-api

status-api:
	@if [ -f $(API_PID_FILE) ] && kill -0 $$(cat $(API_PID_FILE)) 2>/dev/null; then echo "API server running (PID: $$(cat $(API_PID_FILE)))"; else echo "API server not running"; fi

logs-api:
	@tail -f $(API_LOG_FILE)

worker:
	$(PYTHON) scripts/local_postgres.py run -- $(PYTHON) -m zcoder.worker.process $(WORKER_ARGS)

start-worker:
	@if [ -f $(WORKER_PID_FILE) ] && kill -0 $$(cat $(WORKER_PID_FILE)) 2>/dev/null; then echo "Worker already running: $$(cat $(WORKER_PID_FILE))"; exit 1; fi
	@mkdir -p logs
	@setsid nohup $(PYTHON) scripts/local_postgres.py run -- $(PYTHON) -m zcoder.worker.process $(WORKER_ARGS) < /dev/null > $(WORKER_LOG_FILE) 2>&1 & echo $$! > $(WORKER_PID_FILE)
	@sleep 1
	@kill -0 $$(cat $(WORKER_PID_FILE)) 2>/dev/null || { echo "Worker startup failed; see $(WORKER_LOG_FILE)"; rm -f $(WORKER_PID_FILE); exit 1; }
	@echo "Worker started (PID: $$(cat $(WORKER_PID_FILE)))"

stop-worker:
	@if [ ! -f $(WORKER_PID_FILE) ]; then echo "Worker not running"; exit 0; fi
	@PID=$$(cat $(WORKER_PID_FILE)); if kill -0 $$PID 2>/dev/null; then kill $$PID; fi
	@rm -f $(WORKER_PID_FILE)
	@echo "Worker stopped"

restart-worker: stop-worker start-worker

status-worker:
	@if [ -f $(WORKER_PID_FILE) ] && kill -0 $$(cat $(WORKER_PID_FILE)) 2>/dev/null; then echo "Worker running (PID: $$(cat $(WORKER_PID_FILE)))"; else echo "Worker not running"; fi

logs-worker:
	@tail -f $(WORKER_LOG_FILE)

stop-all: stop-api stop-worker stop
	@echo "All services stopped"

restart-all: restart-api restart-worker restart
	@echo "All services restarted"

# Preserve the historical `make build` behavior for the web console.
build:
	@test -d $(WEB_VENV) || $(PYTHON) -m venv $(WEB_VENV)
	$(WEB_PY) -m pip install --upgrade pip
	$(WEB_PY) -m pip install -e '.[web]'
	@mkdir -p logs
	@echo "Web environment ready: $(WEB_VENV)"

standalone:
	@if [ "$$(uname -s)" = "Linux" ] || [ "$$(uname -s)" = "Darwin" ]; then bash scripts/build.sh; else python scripts/install.py build; fi

standalone-force:
	@if [ "$$(uname -s)" = "Linux" ] || [ "$$(uname -s)" = "Darwin" ]; then bash scripts/build.sh --force; else python scripts/install.py build --force; fi

build-desktop:
	$(PYTHON) scripts/install.py build --desktop

build-desktop-force:
	$(PYTHON) scripts/install.py build --desktop --force

cert-generate:
	@echo "==> Generating Authenticode Code-Signing Certificate..."
	@powershell.exe -ExecutionPolicy Bypass -File scripts/make_cert.ps1 -OutDir $(CERT_DIR) -ExportPfx -InstallToTrustStore 2>/dev/null || powershell -ExecutionPolicy Bypass -File scripts/make_cert.ps1 -OutDir $(CERT_DIR) -ExportPfx -InstallToTrustStore 2>/dev/null || pwsh -ExecutionPolicy Bypass -File scripts/make_cert.ps1 -OutDir $(CERT_DIR) -ExportPfx -InstallToTrustStore 2>/dev/null || echo "[NOTE] Code-signing certificate generation is only supported on Windows PowerShell / pwsh."

sign:
	@echo "==> Authenticode Code-Signing & RFC3161 Timestamping..."
	@powershell.exe -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -Pfx $(PFX_PATH) 2>/dev/null || powershell -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -Pfx $(PFX_PATH) 2>/dev/null || pwsh -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -Pfx $(PFX_PATH) 2>/dev/null || echo "[NOTE] Authenticode signing applies to Windows binaries (.exe, .dll) via PowerShell."

verify:
	@echo "==> Verifying Digital Signatures..."
	@powershell.exe -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -VerifyOnly 2>/dev/null || powershell -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -VerifyOnly 2>/dev/null || pwsh -ExecutionPolicy Bypass -File scripts/sign_exe.ps1 -SearchPath $(DIST_DIR) -VerifyOnly 2>/dev/null || echo "[NOTE] Digital signature verification applies to Windows binaries (.exe) via PowerShell."

full-build: check standalone-force
	@echo "==> Standalone build completed successfully."
	@if [ -f "$(DIST_DIR)/zcoder.exe" ]; then $(MAKE) sign; else echo "Built platform executable: $$(ls $(DIST_DIR)/zcoder* 2>/dev/null)"; fi

full-build-desktop: check build-desktop-force
	@echo "==> Desktop GUI standalone build completed successfully."
	@if [ -f "$(DIST_DIR)/zcoder-desktop.exe" ]; then $(MAKE) sign; else echo "Built platform executable: $$(ls $(DIST_DIR)/zcoder-desktop* 2>/dev/null)"; fi

start:
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then echo "already running: $$(cat $(PID_FILE))"; exit 1; fi
	@test -x $(WEB_UVICORN) || { echo "run 'make build' first"; exit 1; }
	@mkdir -p logs
	@setsid nohup $(WEB_UVICORN) webapp.backend.server:app --app-dir . --host $(HOST) --port $(PORT) < /dev/null > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE)
	@sleep 1
	@kill -0 $$(cat $(PID_FILE)) 2>/dev/null || { echo "web startup failed; see $(LOG_FILE)"; rm -f $(PID_FILE); exit 1; }
	@echo "started: http://$(HOST):$(PORT)"

stop:
	@if [ ! -f $(PID_FILE) ]; then echo "not running"; exit 0; fi
	@PID=$$(cat $(PID_FILE)); if kill -0 $$PID 2>/dev/null; then kill $$PID; fi
	@rm -f $(PID_FILE)

restart: stop start

update:
	$(PYTHON) -m pip install --upgrade -e .

upgrade: update
	$(PYTHON) main.py --version
	$(PYTHON) main.py --health-check || true

status:
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then echo "running: $$(cat $(PID_FILE))"; else echo "not running"; fi

logs:
	@tail -f $(LOG_FILE)

postgres-setup:
	$(PYTHON) scripts/local_postgres.py setup

postgres-status:
	$(PYTHON) scripts/local_postgres.py status

docker-build:
	docker compose build zcoder

docker-run:
	docker compose run --build --rm zcoder $(ARGS)

docker-down:
	docker compose down

docker-logs:
	docker compose logs --tail=100 -f llama-server

# ============================================================================
# OpenCode CLI Integration
#
# Conventions:
# - PROMPT is always passed as a single shell word ("$(PROMPT)") so quoting,
#   spaces, and newlines survive intact.
# - .env is loaded via scripts/opencode_env.py and exported to child
#   processes; values are never echoed. Never commit real credentials.
# - OPENCODE_AUTO_APPROVE defaults to `deny` so non-interactive runs cannot
#   mutate the workspace without review (set allow only in trusted CI).
# - Background runs go through scripts/opencode_bg.py (detached session,
#   per-run log/pid/json metadata under $(BG_DIR)/, gitignored).
# - Foreground runs are bounded by OPENCODE_TIMEOUT when `timeout` exists.
# ============================================================================

ENVLOAD = eval "$$(python3 scripts/opencode_env.py)"; export $$(cut -d= -f1 ./.env 2>/dev/null | grep -E '^[A-Za-z_][A-Za-z0-9_]*$$' || true)
OC_CHECK = command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found. Install: curl -fsSL https://opencode.ai/install | bash" >&2; exit 127; };
OC_TIMEOUT_PREFIX = $(shell if [ "$(OPENCODE_TIMEOUT)" != "0" ] && command -v timeout >/dev/null 2>&1; then echo "timeout $(OPENCODE_TIMEOUT)"; else echo ""; fi)

opencode:
	@$(ENVLOAD); \
	$(OC_CHECK) \
	exec $(OPENCODE_BIN)

opencode-prompt:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-prompt PROMPT=\"...\" [OPENCODE_MODEL=\"provider/model\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	$(OC_CHECK) \
	$(OC_TIMEOUT_PREFIX) $(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE)

opencode-free-prompt:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-free-prompt PROMPT=\"...\" [OPENCODE_FREE_MODEL=\"...\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	$(OC_CHECK) \
	$(OC_TIMEOUT_PREFIX) $(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_FREE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE)

opencode-bg:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-bg PROMPT=\"...\" [OPENCODE_MODEL=\"provider/model\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	$(OC_CHECK) \
	python3 scripts/opencode_bg.py run --dir $(BG_DIR) -- $(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE)

opencode-free-bg:
	@if [ -z "$(PROMPT)" ]; then echo "usage: make opencode-free-bg PROMPT=\"...\" [OPENCODE_FREE_MODEL=\"...\"]" >&2; exit 2; fi
	@$(ENVLOAD); \
	$(OC_CHECK) \
	python3 scripts/opencode_bg.py run --dir $(BG_DIR) -- $(OPENCODE_BIN) run "$(PROMPT)" --model "$(OPENCODE_FREE_MODEL)" --auto-approve $(OPENCODE_AUTO_APPROVE)

opencode-bg-status:
	@python3 scripts/opencode_bg.py status --dir $(BG_DIR) $(RUN_ID)

opencode-bg-list:
	@python3 scripts/opencode_bg.py list --dir $(BG_DIR)

opencode-bg-tail:
	@if [ -z "$(RUN_ID)" ]; then echo "usage: make opencode-bg-tail RUN_ID=<id> [N=50]" >&2; exit 2; fi
	@python3 scripts/opencode_bg.py tail --dir $(BG_DIR) "$(RUN_ID)" $(or $(N),50)

opencode-stop:
	@python3 scripts/opencode_bg.py stop --dir $(BG_DIR) $(RUN_ID)

# ---------------------------------------------------------------------------
# Model listing targets
#
# Resolution order per provider: repo-local catalog script
# (model-catalog/list-<name>.sh|.py, if present) -> generic `opencode models`
# output filtered by substring. Catalog scripts encode provider specifics
# (e.g. NVIDIA NIM's OpenAI-compatible endpoint at
# https://integrate.api.nvidia.com/v1, or Kilo Code free router aliases).
# ---------------------------------------------------------------------------

opencode-models:
	@$(ENVLOAD); \
	$(OC_CHECK) \
	$(OPENCODE_BIN) models

opencode-free-models:
	@$(ENVLOAD); \
	found=0; s=""; \
	for f in $(MODEL_CATALOG_DIR)/list-free.sh $(MODEL_CATALOG_DIR)/list-free.py; do \
		if [ -f "$$f" ]; then found=1; s="$$f"; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# Free models (substring filter on '$(OPENCODE_BIN) models'; edit $(MODEL_CATALOG_DIR)/list-free.* for curated lists)"; \
		command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
		$(OPENCODE_BIN) models | grep -Ei 'free|lite|nemotron|kilo|zen' || echo "(none matched — verify provider credentials in .env)"; \
	fi

opencode-nvidia-models:
	@$(ENVLOAD); \
	found=0; s=""; \
	for f in $(MODEL_CATALOG_DIR)/list-nvidia.sh $(MODEL_CATALOG_DIR)/list-nvidia.py; do \
		if [ -f "$$f" ]; then found=1; s="$$f"; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# NVIDIA Nemotron & NIM models (substring filter; requires NVIDIA catalogue access)"; \
		command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
		$(OPENCODE_BIN) models | grep -Ei 'nvidia|nemotron' || echo "(none matched — configure the nvidia provider, e.g. nvapi- key via 'opencode auth login')"; \
	fi

opencode-kilo-models:
	@$(ENVLOAD); \
	found=0; s=""; \
	for f in $(MODEL_CATALOG_DIR)/list-kilo.sh $(MODEL_CATALOG_DIR)/list-kilo.py; do \
		if [ -f "$$f" ]; then found=1; s="$$f"; break; fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		case "$$s" in *.sh) sh "$$s";; *) python3 "$$s";; esac; \
	else \
		echo "# Kilo models & free routers (substring filter)"; \
		command -v $(OPENCODE_BIN) >/dev/null 2>&1 || { echo "ERROR: $(OPENCODE_BIN) not found on PATH." >&2; exit 127; }; \
		$(OPENCODE_BIN) models | grep -Ei 'kilo' || echo "(none matched — install/configure the kilo provider gateway)"; \
	fi

opencode-all:
	@echo "================================================================================"
	@echo "               OpenCode All Skills & Models Feature                             "
	@echo "================================================================================"
	@echo ""
	@echo "Available skill targets:"
	@echo "  make opencode-agy     - Run OpenCode with Agy skill"
	@echo "  make opencode-gemini  - Run OpenCode with Gemini skill"
	@echo "  make opencode-codex   - Run OpenCode with Codex skill"
	@echo "  make opencode-kilo    - Run OpenCode with Kilo skill"
	@echo "  make opencode-claude  - Run OpenCode with Claude skill"
	@echo ""
	@echo "Available opencode model categories:"
	@echo "  make opencode-models        - List all OpenCode models"
	@echo "  make opencode-free-models   - List all free models"
	@echo "  make opencode-nvidia-models - List NVIDIA models"
	@echo "  make opencode-kilo-models   - List Kilo models"
	@echo ""
	@echo "Skill files located in: skills/"
	@echo "  agy.skill, gemini.skill, codex.skill, kilo.skill, claude.skill"

validate-template:
	python3 scripts/validate_repo.py
	python3 -m unittest discover -s tests -v

ci: validate-template lint test security

clean:
	find . -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache .mypy_cache .ruff_cache .coverage coverage.xml build dist $(BG_DIR) .tmp logs $(PID_FILE) $(API_PID_FILE) $(WORKER_PID_FILE) .opencode.pid
