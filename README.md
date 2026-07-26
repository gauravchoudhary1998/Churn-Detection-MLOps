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
make mlflow-ui          # inspect runs/models at http://127.0.0.1:5001
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

**A local file doesn't survive CI's ephemeral runners on its own.** Every GitHub Actions run
starts on a brand-new VM — without help, each run would create its own empty `mlflow.db`, register
its champion as "version 1" every single time, and lose all of it the moment the job ends. The
CI/CD workflow works around this by treating `mlflow.db` the same way DVC treats data: pull the
shared copy from S3 before training, push the updated one back after (`mlflow/` prefix in the same
bucket). To see CI's training history in your own `make mlflow-ui`:

```bash
make mlflow-pull   # fetch the shared history CI has been building
make mlflow-ui
```

Not automatic on every `make train` — most local runs are just iteration, and `make mlflow-push`
is there when you actually want a local result to join the shared history. The accepted
limitation: this doesn't handle concurrent writers safely (two simultaneous CI runs could clobber
each other's history), which is fine for a solo project with sequential pushes but wouldn't be for
a team — the real production fix would be a standing MLflow Tracking Server backed by a proper
database, deliberately not built here to stay serverless/cost-conscious.

## Deploy

```bash
make package-model                              # exports the MLflow champion model to build/model.tar.gz
cd terraform && terraform init && terraform apply   # uploads it to S3, deploys the SageMaker endpoint
```

`make package-model` must run before `terraform apply` — Terraform uploads whatever's currently
at `build/model.tar.gz`, it doesn't build it. Re-run both any time you want to redeploy a newly
trained champion.

Deployment is [SageMaker Serverless Inference](https://docs.aws.amazon.com/sagemaker/latest/dg/serverless-endpoints.html),
not an always-on real-time endpoint — it scales to zero between requests, so there's no idle-hour
billing while the endpoint just exists (deliberate cost-consciousness call, see
[Cost & cleanup](#cost--cleanup)). [src/churn/inference/inference.py](src/churn/inference/inference.py)
implements the four functions AWS's prebuilt scikit-learn container expects
(`model_fn`/`input_fn`/`predict_fn`/`output_fn`); [package.py](src/churn/inference/package.py) exports
the MLflow `@champion` model, re-serializes it as `model.joblib`, and tars it with the inference
script into `model.joblib` + `code/inference.py` — that's genuinely the whole package, no extra
dependencies bundled.

**Two constraints that matter, both about keeping training and serving in lockstep:**
- `requirements.txt` pins `scikit-learn==1.4.2`, not the latest release — that's the newest
  version AWS's prebuilt SageMaker scikit-learn container supports. A model pickled with a newer
  scikit-learn isn't guaranteed to unpickle correctly in an older one.
- The container doesn't have pandas installed, and there's no reliable way to add it at
  deploy time (its own dependency-install mechanism turned out to be broken for this container —
  falls back to a `pip install --user` the serving process can't see on its own `sys.path`, so the
  import fails right after pip reports success). Rather than work around that, `train.py`'s
  `ColumnTransformer` selects feature columns by **position**, not name, so the fitted pipeline
  accepts a plain Python list — `inference.py` builds one straight from the JSON request in a
  fixed column order (`FEATURE_COLUMNS`, must match `data/processed/telco_churn_clean.csv`'s
  column order). No pandas anywhere in the serving path.

Once deployed, test it (run from the `terraform/` directory, or drop `-raw sagemaker_endpoint_name`'s
implicit local dir and add `-chdir=terraform` if running from the repo root):

```bash
cat > /tmp/payload.json <<'EOF'
{"gender":"Female","SeniorCitizen":0,"Partner":"Yes","Dependents":"No","tenure":1,"PhoneService":"No","MultipleLines":"No phone service","InternetService":"DSL","OnlineSecurity":"No","OnlineBackup":"Yes","DeviceProtection":"No","TechSupport":"No","StreamingTV":"No","StreamingMovies":"No","Contract":"Month-to-month","PaperlessBilling":"Yes","PaymentMethod":"Electronic check","MonthlyCharges":29.85,"TotalCharges":29.85}
EOF

aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$(terraform output -raw sagemaker_endpoint_name)" \
  --content-type application/json \
  --cli-binary-format raw-in-base64-out \
  --body file:///tmp/payload.json \
  /tmp/response.json && cat /tmp/response.json
```

`--cli-binary-format raw-in-base64-out` is required with AWS CLI v2 — it treats blob parameters
like `--body` as raw text instead of expecting pre-base64-encoded input, which is the v2 default.
Confirmed working: `[{"churn_probability": 0.8096558319067937, "churn_prediction": 1}]` — matches
the local dry-run prediction exactly, for the same new-customer/month-to-month test record.

The IAM execution role ([terraform/iam.tf](terraform/iam.tf)) is scoped to exactly what the
endpoint needs — read access to its one model artifact prefix in S3, and permission to write its
own CloudWatch logs — rather than the broad `AmazonSageMakerFullAccess` managed policy.

## CI/CD

[.github/workflows/train-validate-deploy.yml](.github/workflows/train-validate-deploy.yml) runs on
every push to `main` that touches `src/churn/`, `config/`, a DVC pointer file, or `terraform/`
(plus manual triggering via `workflow_dispatch`). One job, sequential steps:

```
terraform init (learn the bucket name) → dvc pull → pull shared mlflow.db →
train → push shared mlflow.db → quality gate → package → terraform apply
```

The **quality gate** ([src/churn/training/gate.py](src/churn/training/gate.py)) is what makes this
a real gate and not just automation with extra steps: it checks the freshly-trained champion's
`recall` against a threshold (`config/train_config.yaml`, currently `>= 0.70`) and exits non-zero
if it doesn't clear the bar. GitHub Actions stops the job on any failed step by default — no extra
conditional logic was needed to make "package" and "deploy" not run when the gate fails, that's
just what a failed step does.

Deliberately a **different metric than model selection**: `primary_metric` (ROC-AUC) picks the
best of the candidates trained this run; `quality_gate` decides whether that winner is actually
good enough to ship. For churn, missing an actual churner costs more than a false alarm, so the
gate specifically checks recall rather than reusing the selection metric.

**Two pieces of infrastructure this needed that weren't obvious up front:**
- **Remote Terraform state.** State was local-only (`terraform/terraform.tfstate`, gitignored)
  through Phase 4 — fine when only one laptop ever runs `terraform apply`. Once CI runs it too,
  both need to see the same state or CI will try to recreate everything from scratch and collide
  with what already exists. Fixed with an S3 backend ([terraform/backend.tf](terraform/backend.tf))
  pointing at a **separate, stable-named bucket** — not the DVC data bucket, since that one gets
  destroyed and recreated across `make destroy`/`apply` cycles, which would be self-defeating for
  something meant to persist. That state bucket is created once via plain AWS CLI (not Terraform —
  Terraform can't bootstrap its own backend) and isn't touched by `make destroy`.
- **A scoped CI identity.** [terraform/iam_ci.tf](terraform/iam_ci.tf) creates an IAM user with a
  policy limited to exactly what this pipeline does — the two S3 buckets, the specific SageMaker
  execution role, and this project's specific model/endpoint-config/endpoint resources — not
  account-wide access. Authenticates via a static access key stored as GitHub repository secrets
  (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`), not OIDC federation — simpler to set up, the
  standard tradeoff being a long-lived credential sitting in GitHub's secret store instead of
  short-lived per-run tokens.

## Roadmap

- [x] Phase 1 — Repo scaffold, env setup
- [x] Phase 2 — Data ingestion + DVC versioning (S3 remote)
- [x] Phase 3 — Training + MLflow tracking/registry
- [x] Phase 4 — SageMaker packaging + Terraform infra
- [x] Phase 5 — CI/CD with a real quality gate
- [ ] Phase 6 — Drift monitoring (Evidently + CloudWatch)
- [ ] Phase 7 — Architecture diagram, write-up, cost teardown, resume bullets

## Why X over Y

_Coming in Phase 7 — 2-3 real design decisions with tradeoffs._

## Cost & cleanup

```bash
make destroy   # terraform destroy — tears down the SageMaker endpoint, IAM role, and S3 bucket
```

Interactive — Terraform will ask you to confirm before deleting anything. Run this when you're
done with a session; the serverless endpoint doesn't bill per-hour while idle, but the S3 bucket
and the endpoint's own existence aren't free forever either, and this is a portfolio project, not
a service anyone depends on staying up.

## License

MIT
