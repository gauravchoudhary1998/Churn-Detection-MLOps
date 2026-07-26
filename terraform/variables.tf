variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Null to use the default credential chain."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Prefix used for naming AWS resources."
  type        = string
  default     = "mlops-dvc"
}

variable "tfstate_bucket" {
  description = "Bucket holding Terraform's own state. Must match backend.tf."
  type        = string
  default     = "mlops-tfstate-729723728304"
}
