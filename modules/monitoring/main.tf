resource "aws_sns_topic" "alerts_topic" {
  name = "stock-alerts-${var.env}"

  tags = merge(var.tags, {
    Name    = "stock-alerts-${var.env}"
    Purpose = "Alert notifications for stock pipeline"
  })
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-ingest-errors-${var.env}"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alerts_topic.arn]

  tags = merge(var.tags, {
    Name = "lambda-ingest-errors-${var.env}"
  })
}
