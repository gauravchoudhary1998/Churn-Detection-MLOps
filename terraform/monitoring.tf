resource "aws_cloudwatch_metric_alarm" "data_drift" {
  alarm_name          = "${var.project_name}-data-drift"
  alarm_description   = "Share of feature columns flagged as drifted by the last drift check exceeded the threshold."
  namespace           = "ChurnMLOps"
  metric_name         = "DriftedColumnShare"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0.3
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
