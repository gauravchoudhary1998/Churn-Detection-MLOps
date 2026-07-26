"""Train candidate churn models, log each to MLflow, and register the best one.

Usage:
    python -m churn.training.train
    python -m churn.training.train --config config/train_config.yaml
"""

import argparse
from pathlib import Path

import mlflow
import mlflow.sklearn
import pandas as pd
import yaml
from dotenv import load_dotenv
from mlflow.tracking import MlflowClient
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

from churn.training.evaluate import evaluate

MODEL_REGISTRY = {
    "logistic_regression": LogisticRegression,
    "random_forest": RandomForestClassifier,
}

DEFAULT_CONFIG = Path("config/train_config.yaml")


def load_config(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def ensure_experiment(name: str) -> None:
    # Relative artifact path so it resolves on both local machines and CI.
    if mlflow.get_experiment_by_name(name) is None:
        mlflow.create_experiment(name, artifact_location="mlruns")
    mlflow.set_experiment(name)


def build_pipeline(model_name: str, params: dict, categorical_idx: list, numeric_idx: list) -> Pipeline:
    # Columns selected by position so the pipeline accepts a plain array.
    preprocessor = ColumnTransformer(
        transformers=[
            ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_idx),
            ("num", StandardScaler(), numeric_idx),
        ]
    )
    model = MODEL_REGISTRY[model_name](**params)
    return Pipeline(steps=[("preprocess", preprocessor), ("model", model)])


def train(config: dict) -> dict:
    df = pd.read_csv(config["data_path"])
    target = config["target"]

    X = df.drop(columns=[target])
    y = df[target]

    feature_columns = X.columns.tolist()
    categorical_idx = [feature_columns.index(c) for c in X.select_dtypes(include="object").columns]
    numeric_idx = [feature_columns.index(c) for c in X.select_dtypes(exclude="object").columns]
    print(f"Feature order (inference.py's FEATURE_COLUMNS must match): {feature_columns}")

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=config["test_size"],
        random_state=config["random_state"],
        stratify=y,
    )

    ensure_experiment(config["experiment_name"])

    primary_metric = config["primary_metric"]
    results = []

    for candidate in config["candidates"]:
        name = candidate["name"]
        params = candidate["params"]

        with mlflow.start_run(run_name=name) as run:
            pipeline = build_pipeline(name, params, categorical_idx, numeric_idx)
            pipeline.fit(X_train, y_train)

            y_pred = pipeline.predict(X_test)
            y_proba = pipeline.predict_proba(X_test)[:, 1]
            metrics = evaluate(y_test, y_pred, y_proba)

            mlflow.log_param("model_type", name)
            mlflow.log_params({f"param_{k}": v for k, v in params.items()})
            mlflow.log_metrics(metrics)
            mlflow.sklearn.log_model(pipeline, name="model")

            results.append({"run_id": run.info.run_id, "name": name, **metrics})
            print(f"[{name}] " + " ".join(f"{k}={v:.4f}" for k, v in metrics.items()))

    best = max(results, key=lambda r: r[primary_metric])
    print(f"\nBest candidate by {primary_metric}: {best['name']} ({primary_metric}={best[primary_metric]:.4f})")

    model_uri = f"runs:/{best['run_id']}/model"
    registered_name = config["registered_model_name"]
    registered = mlflow.register_model(model_uri, registered_name)

    client = MlflowClient()
    client.set_registered_model_alias(registered_name, "champion", registered.version)
    print(f"Registered '{registered_name}' version {registered.version} with alias 'champion'")

    return best


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    args = parser.parse_args()

    config = load_config(args.config)
    train(config)


if __name__ == "__main__":
    main()
