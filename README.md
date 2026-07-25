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

## Roadmap

- [x] Phase 1 — Repo scaffold, env setup
- [ ] Phase 2 — Data ingestion + DVC versioning (S3 remote)
- [ ] Phase 3 — Training + MLflow tracking/registry
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
