# Requires build/model.tar.gz to already exist locally — run
# `make package-model` before `terraform apply` (see README).

resource "aws_s3_object" "model_artifact" {
  bucket = aws_s3_bucket.dvc_store.id
  key    = "sagemaker/model.tar.gz"
  source = "${path.module}/../build/model.tar.gz"
  etag   = filemd5("${path.module}/../build/model.tar.gz")
}

# Resolves AWS's prebuilt scikit-learn container image URI for the current
# region instead of hardcoding a per-region ECR account ID. 1.4-2 is
# deliberately not the newest scikit-learn — it's the newest version this
# prebuilt container supports (see requirements.txt for the matching pin).
data "aws_sagemaker_prebuilt_ecr_image" "sklearn" {
  repository_name = "sagemaker-scikit-learn"
  image_tag       = "1.4-2-cpu-py3"
}

resource "aws_sagemaker_model" "churn" {
  name               = "${var.project_name}-churn-classifier"
  execution_role_arn = aws_iam_role.sagemaker_execution.arn

  primary_container {
    image          = data.aws_sagemaker_prebuilt_ecr_image.sklearn.registry_path
    model_data_url = "s3://${aws_s3_bucket.dvc_store.bucket}/${aws_s3_object.model_artifact.key}"

    environment = {
      SAGEMAKER_PROGRAM          = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY = "/opt/ml/model/code"
      # Without this, the container's own mechanism for installing
      # inference.py as a package fails (pip falls back to a --user install
      # the serving process can't see) and the model process crashes with
      # "No module named 'inference'". Pointing PYTHONPATH straight at the
      # script's directory means it's found directly, no install needed.
      PYTHONPATH = "/opt/ml/model/code"
    }
  }
}

resource "aws_sagemaker_endpoint_configuration" "churn" {
  name = "${var.project_name}-churn-endpoint-config"

  production_variants {
    variant_name = "AllTraffic"
    model_name   = aws_sagemaker_model.churn.name

    # Serverless, not a real-time always-on instance: scales to zero between
    # requests, so there's no idle-hour cost while this endpoint just exists.
    serverless_config {
      max_concurrency   = 5
      memory_size_in_mb = 2048
    }
  }
}

resource "aws_sagemaker_endpoint" "churn" {
  name                 = "${var.project_name}-churn-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.churn.name
}
