"""Package the champion model for SageMaker: model.joblib + code/inference.py,
tarred into build/model.tar.gz.

Usage:
    python -m churn.inference.package
"""

import shutil
import tarfile
from pathlib import Path

import joblib
import mlflow.sklearn
from dotenv import load_dotenv

REGISTRY_URI = "models:/churn-classifier@champion"
BUILD_DIR = Path("build")
PACKAGE_DIR = BUILD_DIR / "model_package"
TARBALL_PATH = BUILD_DIR / "model.tar.gz"
INFERENCE_SCRIPT = Path("src/churn/inference/inference.py")


def package() -> Path:
    if PACKAGE_DIR.exists():
        shutil.rmtree(PACKAGE_DIR)
    code_dir = PACKAGE_DIR / "code"
    code_dir.mkdir(parents=True)

    print(f"Loading champion model from {REGISTRY_URI}")
    model = mlflow.sklearn.load_model(REGISTRY_URI)
    joblib.dump(model, PACKAGE_DIR / "model.joblib")

    shutil.copy(INFERENCE_SCRIPT, code_dir / "inference.py")

    with tarfile.open(TARBALL_PATH, "w:gz") as tar:
        tar.add(PACKAGE_DIR / "model.joblib", arcname="model.joblib")
        tar.add(code_dir, arcname="code")

    size_kb = TARBALL_PATH.stat().st_size / 1024
    print(f"Wrote {TARBALL_PATH} ({size_kb:.1f} KB)")
    return TARBALL_PATH


def main() -> None:
    load_dotenv()
    package()


if __name__ == "__main__":
    main()
