data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "sagemaker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sagemaker_execution" {
  name               = "${var.project_name}-sagemaker-execution"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_role.json
}

# Deliberately scoped instead of attaching the AmazonSageMakerFullAccess
# managed policy: this role can only read the one model artifact prefix,
# pull the one prebuilt container image it's deployed against, and write its
# own CloudWatch logs/metrics — nothing else in the account.
data "aws_iam_policy_document" "sagemaker_execution" {
  statement {
    sid       = "ReadModelArtifact"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.dvc_store.arn}/sagemaker/*"]
  }

  statement {
    sid       = "ListModelArtifactPrefix"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.dvc_store.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["sagemaker/*"]
    }
  }

  statement {
    sid = "EndpointLogging"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    # Actual log group SageMaker creates is /aws/sagemaker/Endpoints/<endpoint-name>.
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"]
  }

  statement {
    sid       = "EndpointMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"] # PutMetricData has no resource-level permissions to scope to.
  }

  # SageMaker uses this role's credentials, not a separate service-level
  # pull, to fetch the container image — this is required even though it's
  # an AWS-owned prebuilt image, not a custom one. Confirmed against AWS's
  # own CreateModel execution-role docs (initially missed this).
  statement {
    sid       = "PullPrebuiltContainerAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # This action has no resource-level permissions either.
  }

  statement {
    sid = "PullPrebuiltContainerImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_sagemaker_prebuilt_ecr_image.sklearn.registry_id}:repository/sagemaker-scikit-learn"
    ]
  }
}

resource "aws_iam_role_policy" "sagemaker_execution" {
  name   = "${var.project_name}-sagemaker-execution-policy"
  role   = aws_iam_role.sagemaker_execution.id
  policy = data.aws_iam_policy_document.sagemaker_execution.json
}
