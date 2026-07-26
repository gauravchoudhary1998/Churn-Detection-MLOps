# IAM identity for GitHub Actions (static access key, per user's choice —
# no OIDC federation in this project). Scoped to exactly what the CI
# pipeline does: `dvc pull` + syncing the shared mlflow.db (both just object
# access in the data bucket), read/write Terraform state (the separate
# state bucket), and manage this project's specific SageMaker + IAM
# resources — not account-wide access.

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
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole",
    ]
    resources = [aws_iam_role.sagemaker_execution.arn]
  }

  # Every `terraform apply` refreshes every resource in state, including the
  # CI user's own entries — so the CI user needs permission to read/manage
  # itself, not just the resources it manages. Self-referential, but that's
  # expected: this identity is Terraform-managed like everything else here,
  # not a special case exempt from the same lifecycle.
  statement {
    sid = "ManageSelf"
    actions = [
      "iam:CreateUser",
      "iam:GetUser",
      "iam:UpdateUser",
      "iam:DeleteUser",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:ListUserTags",
      "iam:ListAttachedUserPolicies",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
    ]
    resources = [aws_iam_user.ci.arn]
  }

  # Managed, not inline (aws_iam_user_policy hit IAM's 2048-byte inline
  # policy cap once this file grew past a few statements — a hard AWS
  # limit, not something to work around by trimming permissions). A
  # managed policy allows up to 6144 characters, real headroom for future
  # phases. Resource is a manually-constructed ARN, not
  # aws_iam_policy.ci.arn — referencing the resource's own output here
  # would make the policy document depend on the very policy resource it
  # defines, a real circular dependency Terraform can't resolve.
  statement {
    sid = "ManageOwnPolicy"
    actions = [
      "iam:CreatePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:DeletePolicy",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:ListPolicyTags",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-ci-policy"]
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

  # Manages the alarm *definition* only — CI's terraform apply creates and
  # refreshes this resource on every run, same as everything else in state.
  # The metric it watches is pushed separately, manually, by the user's own
  # local `make check-drift` (see monitoring.tf) — not by CI.
  statement {
    sid = "ManageDriftAlarm"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = ["arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-data-drift"]
  }
}

resource "aws_iam_policy" "ci" {
  name   = "${var.project_name}-ci-policy"
  policy = data.aws_iam_policy_document.ci.json
}

resource "aws_iam_user_policy_attachment" "ci" {
  user       = aws_iam_user.ci.name
  policy_arn = aws_iam_policy.ci.arn
}
