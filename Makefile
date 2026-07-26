PYTHON := /opt/homebrew/opt/python@3.11/bin/python3.11
VENV := .venv
VENV_BIN := $(VENV)/bin

.PHONY: setup install download-data prepare-data train gate mlflow-ui mlflow-pull mlflow-push package-model check-drift destroy clean

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

# Manual, on-demand — no live traffic to check drift against, so this
# compares a synthetic drifted sample against the training baseline and
# reports the result to CloudWatch (see terraform/monitoring.tf for the
# alarm watching it). Point at a real CSV with --current instead once
# there's real data to check.
check-drift:
	$(VENV_BIN)/python -m churn.monitoring.drift --synthetic

# CI shares its training history through S3 the same way it shares data —
# pull before you want to see CI's runs in `make mlflow-ui`, push after a
# local run you want to keep in that shared history. Not automatic on every
# `make train`, deliberately: most local runs are just iteration, not
# everything needs to be published.
mlflow-pull:
	@BUCKET=$$(cd terraform && terraform output -raw dvc_bucket_name); \
	aws s3 cp "s3://$$BUCKET/mlflow/mlflow.db" mlflow.db

mlflow-push:
	@BUCKET=$$(cd terraform && terraform output -raw dvc_bucket_name); \
	aws s3 cp mlflow.db "s3://$$BUCKET/mlflow/mlflow.db"

# Tears down every billable AWS resource this project created (SageMaker
# endpoint, IAM role, S3 bucket). Interactive — terraform will ask you to
# type "yes" before it deletes anything.
destroy:
	cd terraform && terraform destroy

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf build
