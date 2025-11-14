output "lambda_function_name" {
  value = aws_lambda_function.stock_producer.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.stock_producer.arn
}
