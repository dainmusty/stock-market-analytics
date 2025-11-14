output "sns_topic_arn" {
  value = aws_sns_topic.alerts_topic.arn
}

output "sns_subscription_arn" {
  value = aws_sns_topic_subscription.email_subscription.arn
}

output "cloudwatch_alarm_name" {
  value = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
}
