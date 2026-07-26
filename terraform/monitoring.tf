# Watches the custom metric src/churn/monitoring/drift.py pushes
# (ChurnMLOps/DriftedColumnShare) whenever the drift check is run manually
# (see README — no live traffic in this project, so this isn't scheduled).
# No SNS/notification wired up: alarm state is visible in the CloudWatch
# console/CLI when it fires, deliberately kept that simple for this project.

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

  # This metric is only pushed when someone runs `make check-drift` — not
  # continuously — so a lack of recent data points must not itself count as
  # a breach.
  treat_missing_data = "notBreaching"
}
