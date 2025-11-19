# 3 options to create a lambda function:
# 1. Upload a .zip file to S3 and reference it here (preferred for
# 2. you can create the function locally using "lambda_function.zip"
# 3.source_code_hash = filebase64sha256("${path.module}/lambda/ingest.zip")
########################
# Lambda: Stock Ingest
########################

resource "aws_lambda_function" "ingest" {
  function_name = "stock-ingest-${var.env}"

  # 👇 Use local ZIP instead of S3 bucket
  filename         = "${path.module}/modules/lambda_ingest/stock_ingestor.zip"
  source_code_hash = filebase64sha256("${path.module}/modules/lambda_ingest/stock_ingestor.zip")

  handler          = "app.lambda_handler"        # keep your handler
  runtime          = "python3.11"
  role             = var.lambda_role_arn
  timeout          = 30
  memory_size      = 256

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
