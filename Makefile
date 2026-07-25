PYTHON := /opt/homebrew/opt/python@3.11/bin/python3.11
VENV := .venv
VENV_BIN := $(VENV)/bin

.PHONY: setup install download-data prepare-data train mlflow-ui clean

setup:
	$(PYTHON) -m venv $(VENV)
	$(VENV_BIN)/pip install --upgrade pip
	$(VENV_BIN)/pip install -r requirements-dev.txt
	$(VENV_BIN)/pip install -e .

install:
	$(VENV_BIN)/pip install -r requirements-dev.txt

download-data:
	PATH="$(abspath $(VENV_BIN)):$$PATH" bash scripts/download_data.sh

prepare-data:
	$(VENV_BIN)/python -m churn.data.prepare

train:
	$(VENV_BIN)/python -m churn.training.train

mlflow-ui:
	# port 5000 is macOS's AirPlay Receiver (ControlCenter) on most machines —
	# it'll intercept requests and return 403, so this stays off the default port.
	$(VENV_BIN)/mlflow ui --backend-store-uri sqlite:///mlflow.db --port 5001

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +

# `make destroy` (AWS teardown) lands in Phase 4 once Terraform-managed
# resources exist to tear down.
