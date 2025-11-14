resource "aws_lambda_function" "ingest" {
  function_name = var.function_name
  s3_bucket     = var.artifacts_bucket_name
  s3_key        = var.artifacts_key
  handler       = "app.lambda_handler"
  runtime       = "python3.11"
  role          = var.lambda_role_arn
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      RAW_BUCKET = var.raw_bucket_name
      DDB_TABLE  = var.ddb_table_name
    }
  }

  tags = merge(var.tags, {
    Name = "stock-ingest-${var.env}"
  })
}

resource "aws_lambda_event_source_mapping" "kinesis_to_lambda" {
  event_source_arn  = var.kinesis_stream_arn
  function_name     = aws_lambda_function.ingest.arn
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}
