########################
# Lambda: Stock Producer
########################

resource "aws_lambda_function" "stock_producer" {
  function_name = var.function_name
  s3_bucket     = var.artifacts_bucket
  s3_key        = var.artifacts_key                # e.g. "lambda/stock_producer.zip"

  # 👇 Handler is now configurable (default is .main for dev)
  handler       = var.lambda_handler               # e.g. "stock_producer.main" or "stock_producer.lambda_handler"
  runtime       = var.lambda_runtime
  role          = var.lambda_producer_role_arn
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  environment {
    variables = {
      STREAM_NAME = var.stream_name
      REGION      = var.region
    }
  }

  depends_on = [
    var.lambda_producer_role_basic_attachment,
    var.lambda_producer_role_kinesis_attachment,
    var.artifacts_bucket
  ]

  tags = merge(var.tags, {
    Name = var.function_name
  })
}

##########################################
# EventBridge Rule: Schedule every minute
##########################################

resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = var.event_rule_name
  schedule_expression = var.schedule_expression    # e.g. "rate(1 minute)"
  description         = "Triggers stock producer Lambda every minute"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "stock-producer"
  arn       = aws_lambda_function.stock_producer.arn
}

##########################################
# Lambda Permission: Allow EventBridge
##########################################

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock_producer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}
