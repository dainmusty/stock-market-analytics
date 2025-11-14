resource "aws_kinesis_stream" "stock_stream" {
  name             = var.kinesis_stream_name
  shard_count      = var.shard_count
  retention_period = var.retention_hours

  tags = merge(var.tags, {
    Name    = "stock-stream-${var.env}"
    Purpose = "Ingest stock data"
  })
}
