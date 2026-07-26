variable "aws_region" {
  description = "AWS region for all resources in this project."
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. Leave null to use the default credential chain (env vars, SSO, etc.) — must be null in CI, which authenticates via env vars only and has no shared config file. Set it locally via a gitignored terraform.tfvars, not by changing this default."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Prefix used for naming AWS resources."
  type        = string
  default     = "mlops-dvc"
}

variable "tfstate_bucket" {
  description = "Name of the separate, stable bucket holding Terraform's own state (created once, outside Terraform — see backend.tf). Not the same as the DVC data bucket. Must match backend.tf's literal bucket name (that block can't reference this variable)."
  type        = string
  default     = "mlops-tfstate-729723728304"
}
