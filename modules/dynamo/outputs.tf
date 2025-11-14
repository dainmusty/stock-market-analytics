output "table_arn" {
  description = "ARN of the DynamoDB processed table"
  value       = aws_dynamodb_table.processed.arn
}

output "table_name" {
  description = "Name of the DynamoDB processed table"
  value       = aws_dynamodb_table.processed.name
}
