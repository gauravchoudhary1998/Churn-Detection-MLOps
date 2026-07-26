output "dvc_bucket_name" {
  description = "S3 bucket name to use as the DVC remote (s3://<this>/dvc-store)."
  value       = aws_s3_bucket.dvc_store.bucket
}

output "sagemaker_endpoint_name" {
  description = "Endpoint name to pass to `aws sagemaker-runtime invoke-endpoint`."
  value       = aws_sagemaker_endpoint.churn.name
}

output "drift_alarm_name" {
  description = "CloudWatch alarm watching data drift — `aws cloudwatch describe-alarms --alarm-names <this>` to check its state."
  value       = aws_cloudwatch_metric_alarm.data_drift.alarm_name
}

