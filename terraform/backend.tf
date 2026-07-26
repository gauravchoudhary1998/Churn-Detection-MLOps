# Remote state, required once GitHub Actions runs `terraform apply` too —
# without this, CI and your local machine would each think they're the only
# one managing this infra and collide. Points at a separate, stable bucket
# (not the DVC data bucket, which gets destroyed/recreated across
# `make destroy`/`apply` cycles — see README's CI/CD section for why).
#
# Backend blocks can't reference variables or resources (Terraform needs
# this before it can evaluate anything else), so the bucket name is a
# literal here, not var.tfstate_bucket — that variable exists separately for
# terraform/iam_ci.tf's IAM policy, which CAN reference variables.
terraform {
  backend "s3" {
    bucket       = "mlops-tfstate-729723728304"
    key          = "churn-detection-mlops/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
