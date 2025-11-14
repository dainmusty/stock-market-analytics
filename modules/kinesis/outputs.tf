output "kinesis_stream_arn" {
  value = aws_kinesis_stream.stock_stream.arn
}

output "kinesis_stream_name" {
  value = aws_kinesis_stream.stock_stream.name
}
