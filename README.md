# Customer Churn Prediction — AWS-Native MLOps Pipeline

An end-to-end, production-style ML pipeline for predicting telecom customer churn.
The focus is the *pipeline*, not the model: data versioning, experiment tracking,
infrastructure as code, an automated quality gate, and monitoring — the parts that
turn a notebook model into something a team could actually operate.

> Status: work in progress, built phase by phase. See [Roadmap](#roadmap) below.

## Architecture

_Diagram coming in Phase 7._

## Tech stack

| Layer                | Tool                                   |
|-----------------------|-----------------------------------------|
| Data versioning        | DVC (S3 remote)                        |
| Experiment tracking    | MLflow (tracking + model registry)     |
| Model                    | scikit-learn                          |
| Training / deployment   | AWS SageMaker                          |
| Infrastructure as code  | Terraform                              |
| CI/CD                     | GitHub Actions (train → validate → deploy) |
| Drift monitoring          | Evidently AI + CloudWatch alarm       |

## Repo structure

```
.
├── .github/workflows/   # CI/CD pipelines (Phase 5)
├── config/              # thresholds, hyperparameters
├── data/                # DVC-tracked raw/processed data (not in git)
├── docs/                # architecture diagram, write-ups
├── notebooks/           # exploratory analysis only — not part of the pipeline
├── scripts/             # one-off / operational scripts
├── src/churn/
│   ├── data/            # data loading & preprocessing
│   ├── training/         # training + evaluation
│   ├── inference/         # SageMaker inference entry point
│   └── monitoring/         # Evidently drift checks
├── terraform/            # AWS infra: IAM roles, S3, endpoint config
├── Makefile
└── requirements*.txt
```

## Setup

Requires Python 3.11 (see `Makefile` — MLOps tooling here lags behind the newest
Python releases, so this project pins to 3.11 rather than the system default).

```bash
make setup      # creates .venv, installs dev deps, installs the package in editable mode
```

Copy `.env.example` to `.env` and fill in AWS / Kaggle credentials before running
data or training steps.

## Data

The dataset is the [Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)
dataset from Kaggle, versioned with DVC against an S3 remote (bucket provisioned
by `terraform/`, not created by hand).

```bash
# One-time infra: creates the S3 bucket DVC pushes to
cd terraform && terraform init && terraform apply

# Pull the raw CSV from Kaggle (needs a Kaggle API token — see .env.example)
make download-data

# Clean it: drop customerID, fix TotalCharges, encode the target
make prepare-data

# Version both raw and processed data with DVC (bucket name comes from
# `terraform output dvc_bucket_name`)
dvc add data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv data/processed/telco_churn_clean.csv
dvc remote add -d storage s3://<dvc-bucket-name>/dvc-store
dvc push
```

Data is ~26.6% churn — imbalanced enough that model evaluation needs to lead
with precision/recall/ROC-AUC, not raw accuracy.

## Training

```bash
make train              # trains all candidates, logs to MLflow, registers the best
make mlflow-ui          # inspect runs/models at http://127.0.0.1:5000
```

[src/churn/training/train.py](src/churn/training/train.py) trains every candidate listed in
[config/train_config.yaml](config/train_config.yaml) (currently logistic regression and random
forest, both `class_weight="balanced"` to account for the imbalance), logs params/metrics/model
for each as its own MLflow run under the `churn-prediction` experiment, then registers the
candidate with the best ROC-AUC as `churn-classifier` in the MLflow Model Registry and tags it
with the `champion` alias.

Tracking backend is SQLite (`MLFLOW_TRACKING_URI=sqlite:///mlflow.db`), not the plain file
store — the Model Registry requires a database-backed store, so a plain `file:` store would
train and log fine but fail at the registration step. Everything runs locally, no server
process or AWS resources needed for this phase.

## Roadmap

- [x] Phase 1 — Repo scaffold, env setup
- [x] Phase 2 — Data ingestion + DVC versioning (S3 remote)
- [x] Phase 3 — Training + MLflow tracking/registry
- [ ] Phase 4 — SageMaker packaging + Terraform infra
- [ ] Phase 5 — CI/CD with a real quality gate
- [ ] Phase 6 — Drift monitoring (Evidently + CloudWatch)
- [ ] Phase 7 — Architecture diagram, write-up, cost teardown, resume bullets

## Why X over Y

_Coming in Phase 7 — 2-3 real design decisions with tradeoffs._

## Cost & cleanup

_Coming in Phase 4 onward. `make destroy` will tear down all billable AWS
resources created by this project._

## License

MIT
