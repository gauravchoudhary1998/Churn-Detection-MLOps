"""Clean the raw Telco Customer Churn CSV and write a model-ready version.

Usage:
    python -m churn.data.prepare
    python -m churn.data.prepare --input data/raw/foo.csv --output data/processed/bar.csv
"""

import argparse
from pathlib import Path

import pandas as pd

RAW_FILENAME = "WA_Fn-UseC_-Telco-Customer-Churn.csv"
DEFAULT_INPUT = Path("data/raw") / RAW_FILENAME
DEFAULT_OUTPUT = Path("data/processed") / "telco_churn_clean.csv"


def prepare(input_path: Path, output_path: Path) -> pd.DataFrame:
    df = pd.read_csv(input_path)

    df = df.drop(columns=["customerID"])

    # TotalCharges is stored as object dtype because a handful of rows (new
    # customers with 0 tenure) have it as an empty string instead of 0.
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")
    before = len(df)
    df = df.dropna(subset=["TotalCharges"])
    dropped = before - len(df)

    df["Churn"] = df["Churn"].map({"Yes": 1, "No": 0})

    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    churn_rate = df["Churn"].mean()
    print(f"Rows in:  {before}")
    print(f"Rows out: {len(df)} ({dropped} dropped for missing TotalCharges)")
    print(f"Churn rate: {churn_rate:.1%} — confirms class imbalance, plan metrics accordingly")
    print(f"Wrote {output_path}")

    return df


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    prepare(args.input, args.output)


if __name__ == "__main__":
    main()
