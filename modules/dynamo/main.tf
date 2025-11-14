resource "aws_dynamodb_table" "processed" {
  name           = "stock-processed-${var.env}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name    = "stock-processed-${var.env}"
    Purpose = "Processed stock data"
  })
}
