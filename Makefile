PYTHON := /opt/homebrew/opt/python@3.11/bin/python3.11
VENV := .venv
VENV_BIN := $(VENV)/bin

.PHONY: setup install clean

setup:
	$(PYTHON) -m venv $(VENV)
	$(VENV_BIN)/pip install --upgrade pip
	$(VENV_BIN)/pip install -r requirements-dev.txt
	$(VENV_BIN)/pip install -e .

install:
	$(VENV_BIN)/pip install -r requirements-dev.txt

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +

# `make destroy` (AWS teardown) lands in Phase 4 once Terraform-managed
# resources exist to tear down.
