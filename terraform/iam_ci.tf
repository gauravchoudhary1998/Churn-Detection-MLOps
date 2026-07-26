# IAM identity for GitHub Actions (static access key, per user's choice —
# no OIDC federation in this project). Scoped to exactly what the CI
# pipeline does: `dvc pull` (read the data bucket), read/write Terraform
# state (the separate state bucket), and manage this project's specific
# SageMaker + IAM resources — not account-wide access.

resource "aws_iam_user" "ci" {
  name = "${var.project_name}-ci"
}

data "aws_iam_policy_document" "ci" {
  # s3:* rather than an exact action list: scoped tightly to two specific
  # buckets, but covers both `dvc pull`/`dvc push` object access AND
  # Terraform managing the DVC bucket's own config (versioning, encryption,
  # lifecycle) AND the state bucket's object/lockfile read-write — enumerating
  # every individual S3 API Terraform might call is fragile, the bucket-level
  # scoping is what actually keeps this least-privilege.
  statement {
    sid     = "DataAndStateBuckets"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.dvc_store.arn,
      "${aws_s3_bucket.dvc_store.arn}/*",
      "arn:aws:s3:::${var.tfstate_bucket}",
      "arn:aws:s3:::${var.tfstate_bucket}/*",
    ]
  }

  statement {
    sid = "ManageSagemakerExecutionRole"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:PassRole",
    ]
    resources = [aws_iam_role.sagemaker_execution.arn]
  }

  statement {
    sid = "ManageSagemakerResources"
    actions = [
      "sagemaker:CreateModel",
      "sagemaker:DeleteModel",
      "sagemaker:DescribeModel",
      "sagemaker:CreateEndpointConfig",
      "sagemaker:DeleteEndpointConfig",
      "sagemaker:DescribeEndpointConfig",
      "sagemaker:CreateEndpoint",
      "sagemaker:UpdateEndpoint",
      "sagemaker:DeleteEndpoint",
      "sagemaker:DescribeEndpoint",
      "sagemaker:AddTags",
      "sagemaker:ListTags",
    ]
    resources = [
      aws_sagemaker_model.churn.arn,
      aws_sagemaker_endpoint_configuration.churn.arn,
      aws_sagemaker_endpoint.churn.arn,
    ]
  }

  statement {
    sid       = "CallerIdentity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"] # Doesn't support resource-level scoping.
  }
}

resource "aws_iam_user_policy" "ci" {
  name   = "${var.project_name}-ci-policy"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci.json
}
