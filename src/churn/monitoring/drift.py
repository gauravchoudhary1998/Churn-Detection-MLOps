"""Compares current data against the training baseline using Evidently and
reports a summary metric to CloudWatch.

Usage:
    python -m churn.monitoring.drift --synthetic
    python -m churn.monitoring.drift --current path/to/new_data.csv
    python -m churn.monitoring.drift --synthetic --skip-cloudwatch   # local testing, no AWS
"""

import argparse
import os
from pathlib import Path

import boto3
import pandas as pd
from dotenv import load_dotenv
from evidently import Dataset, Report
from evidently.presets import DataDriftPreset

REFERENCE_PATH = Path("data/processed/telco_churn_clean.csv")
CLOUDWATCH_NAMESPACE = "ChurnMLOps"
CLOUDWATCH_METRIC_NAME = "DriftedColumnShare"


def make_synthetic_current(reference: pd.DataFrame) -> pd.DataFrame:
    current = reference.copy()
    current["MonthlyCharges"] = current["MonthlyCharges"] * 3.0
    current["Contract"] = "Month-to-month"
    return current


def check_drift(reference: pd.DataFrame, current: pd.DataFrame) -> dict:
    report = Report([DataDriftPreset()])
    snapshot = report.run(
        reference_data=Dataset.from_pandas(reference),
        current_data=Dataset.from_pandas(current),
    )
    for metric in snapshot.dict()["metrics"]:
        if metric["metric_name"].startswith("DriftedColumnsCount"):
            return metric["value"]
    raise RuntimeError("DriftedColumnsCount metric not found in Evidently report")


def report_to_cloudwatch(share: float, region: str) -> None:
    client = boto3.client("cloudwatch", region_name=region)
    client.put_metric_data(
        Namespace=CLOUDWATCH_NAMESPACE,
        MetricData=[{"MetricName": CLOUDWATCH_METRIC_NAME, "Value": share, "Unit": "None"}],
    )


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--current", type=Path, help="CSV of new data to check for drift")
    source.add_argument(
        "--synthetic", action="store_true", help="Generate a synthetic drifted sample instead"
    )
    parser.add_argument(
        "--skip-cloudwatch", action="store_true", help="Print the result without reporting it"
    )
    args = parser.parse_args()

    reference = pd.read_csv(REFERENCE_PATH)
    current = make_synthetic_current(reference) if args.synthetic else pd.read_csv(args.current)

    result = check_drift(reference, current)
    count, share = result["count"], result["share"]
    print(f"Drifted columns: {int(count)} ({share:.1%} of {reference.shape[1]} columns)")

    if args.skip_cloudwatch:
        return

    region = os.environ.get("AWS_REGION", "us-west-1")
    report_to_cloudwatch(share, region)
    print(f"Reported {CLOUDWATCH_NAMESPACE}/{CLOUDWATCH_METRIC_NAME}={share} to CloudWatch ({region})")


if __name__ == "__main__":
    main()
