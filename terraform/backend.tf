# Bucket name is a literal: backend blocks can't reference variables.
terraform {
  backend "s3" {
    bucket       = "mlops-tfstate-729723728304"
    key          = "churn-detection-mlops/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
