variable "aws_region" {
  description = "AWS region for all resources in this project."
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. Leave null to use the default credential chain (env vars, SSO, etc.)."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Prefix used for naming AWS resources."
  type        = string
  default     = "mlops-dvc"
}
