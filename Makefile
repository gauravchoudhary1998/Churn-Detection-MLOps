PYTHON := /opt/homebrew/opt/python@3.11/bin/python3.11
VENV := .venv
VENV_BIN := $(VENV)/bin

.PHONY: setup install download-data prepare-data train gate mlflow-ui package-model destroy clean

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

gate:
	$(VENV_BIN)/python -m churn.training.gate

mlflow-ui:
	# port 5000 is macOS's AirPlay Receiver (ControlCenter) on most machines —
	# it'll intercept requests and return 403, so this stays off the default port.
	$(VENV_BIN)/mlflow ui --backend-store-uri sqlite:///mlflow.db --port 5001

package-model:
	$(VENV_BIN)/python -m churn.inference.package

# Tears down every billable AWS resource this project created (SageMaker
# endpoint, IAM role, S3 bucket). Interactive — terraform will ask you to
# type "yes" before it deletes anything.
destroy:
	cd terraform && terraform destroy

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf build
