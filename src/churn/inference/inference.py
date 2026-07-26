"""SageMaker inference entry point: model_fn, input_fn, predict_fn, output_fn."""

import json
import os

import joblib

MODEL_FILENAME = "model.joblib"

# Must match data/processed/telco_churn_clean.csv's column order.
FEATURE_COLUMNS = [
    "gender", "SeniorCitizen", "Partner", "Dependents", "tenure",
    "PhoneService", "MultipleLines", "InternetService", "OnlineSecurity",
    "OnlineBackup", "DeviceProtection", "TechSupport", "StreamingTV",
    "StreamingMovies", "Contract", "PaperlessBilling", "PaymentMethod",
    "MonthlyCharges", "TotalCharges",
]


def model_fn(model_dir):
    return joblib.load(os.path.join(model_dir, MODEL_FILENAME))


def input_fn(request_body, request_content_type):
    if request_content_type != "application/json":
        raise ValueError(f"Unsupported content type: {request_content_type}")

    payload = json.loads(request_body)
    records = payload if isinstance(payload, list) else [payload]
    return [[record[col] for col in FEATURE_COLUMNS] for record in records]


def predict_fn(input_data, model):
    probabilities = model.predict_proba(input_data)[:, 1]
    predictions = model.predict(input_data)
    return [
        {"churn_probability": float(prob), "churn_prediction": int(pred)}
        for prob, pred in zip(probabilities, predictions)
    ]


def output_fn(prediction, response_content_type):
    if response_content_type != "application/json":
        raise ValueError(f"Unsupported accept type: {response_content_type}")
    return json.dumps(prediction)
