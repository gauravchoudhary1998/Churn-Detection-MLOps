#!/usr/bin/env bash
# Downloads the Telco Customer Churn dataset from Kaggle into data/raw/.
# Requires Kaggle API credentials: either ~/.kaggle/kaggle.json, or
# KAGGLE_USERNAME / KAGGLE_KEY exported (e.g. via `set -a && source .env && set +a`).
set -euo pipefail

DATASET="blastchar/telco-customer-churn"
OUT_DIR="data/raw"

mkdir -p "$OUT_DIR"
kaggle datasets download -d "$DATASET" -p "$OUT_DIR" --unzip

echo "Downloaded to $OUT_DIR:"
ls -la "$OUT_DIR"
