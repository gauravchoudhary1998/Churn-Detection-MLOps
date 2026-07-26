output "dvc_bucket_name" {
  description = "S3 bucket used as the DVC remote."
  value       = aws_s3_bucket.dvc_store.bucket
}

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name."
  value       = aws_sagemaker_endpoint.churn.name
}

output "drift_alarm_name" {
  description = "CloudWatch alarm watching data drift."
  value       = aws_cloudwatch_metric_alarm.data_drift.alarm_name
}
