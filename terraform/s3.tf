resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "dvc_store" {
  bucket        = "${var.project_name}-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Project = "churn-detection-mlops"
    Purpose = "dvc-remote-storage"
  }
}

resource "aws_s3_bucket_versioning" "dvc_store" {
  bucket = aws_s3_bucket.dvc_store.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dvc_store" {
  bucket = aws_s3_bucket.dvc_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dvc_store" {
  bucket = aws_s3_bucket.dvc_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "dvc_store" {
  bucket = aws_s3_bucket.dvc_store.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
