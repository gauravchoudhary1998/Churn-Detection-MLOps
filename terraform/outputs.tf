output "dvc_bucket_name" {
  description = "S3 bucket name to use as the DVC remote (s3://<this>/dvc-store)."
  value       = aws_s3_bucket.dvc_store.bucket
}
