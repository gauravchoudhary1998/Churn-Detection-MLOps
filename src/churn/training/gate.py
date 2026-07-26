"""Quality gate for the champion model. Checks the metrics train.py already
logged for the current champion against a configured threshold and exits
non-zero if it doesn't clear the bar.

Usage:
    python -m churn.training.gate
    python -m churn.training.gate --config config/train_config.yaml
"""

import argparse
import sys
from pathlib import Path

import yaml
from dotenv import load_dotenv
from mlflow.tracking import MlflowClient

DEFAULT_CONFIG = Path("config/train_config.yaml")


def load_config(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def check_gate(config: dict) -> bool:
    client = MlflowClient()
    registered_name = config["registered_model_name"]
    metric_name = config["quality_gate"]["metric"]
    min_value = config["quality_gate"]["min_value"]

    champion = client.get_model_version_by_alias(registered_name, "champion")
    run = client.get_run(champion.run_id)
    value = run.data.metrics.get(metric_name)

    if value is None:
        print(f"FAIL: run for champion version {champion.version} has no metric '{metric_name}'")
        return False

    passed = value >= min_value
    status = "PASS" if passed else "FAIL"
    print(
        f"{status}: {metric_name}={value:.4f} (threshold: >= {min_value}) "
        f"— model version {champion.version}"
    )
    return passed


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    args = parser.parse_args()

    config = load_config(args.config)
    passed = check_gate(config)
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
