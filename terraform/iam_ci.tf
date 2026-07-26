resource "aws_iam_user" "ci" {
  name = "${var.project_name}-ci"
}

data "aws_iam_policy_document" "ci" {
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

  # ARN constructed manually, not aws_iam_policy.ci.arn: referencing the
  # resource here would create a circular dependency on the policy document
  # that defines it.
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
    resources = ["*"]
  }

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
