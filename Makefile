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
	# port 5000 conflicts with macOS AirPlay Receiver
	$(VENV_BIN)/mlflow ui --backend-store-uri sqlite:///mlflow.db --port 5001

package-model:
	$(VENV_BIN)/python -m churn.inference.package

check-drift:
	$(VENV_BIN)/python -m churn.monitoring.drift --synthetic

mlflow-pull:
	@BUCKET=$$(cd terraform && terraform output -raw dvc_bucket_name); \
	aws s3 cp "s3://$$BUCKET/mlflow/mlflow.db" mlflow.db

mlflow-push:
	@BUCKET=$$(cd terraform && terraform output -raw dvc_bucket_name); \
	aws s3 cp mlflow.db "s3://$$BUCKET/mlflow/mlflow.db"

destroy:
	cd terraform && terraform destroy

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf build
