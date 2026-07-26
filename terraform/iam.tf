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
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"]
  }

  statement {
    sid       = "EndpointMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid       = "PullPrebuiltContainerAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
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
