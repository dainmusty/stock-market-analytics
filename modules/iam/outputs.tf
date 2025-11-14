output "lambda_ingest_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_ingest.arn
}

output "lambda_producer_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_producer.arn
}

output "lambda_producer_role_basic_attachment" {
  description = "Lambda Producer Role Basic Execution Policy Attachment"
  value       = aws_iam_role_policy_attachment.lambda_basic.id
}
output "lambda_producer_role_kinesis_attachment" {
  description = "Lambda Producer Role Kinesis Access Policy Attachment"
  value       = aws_iam_role_policy_attachment.lambda_kinesis.id
} 

output "glue_role_arn" {
  description = "ARN of the Glue execution role"
  value       = aws_iam_role.glue_exec.arn
}


# ------------------------------------------------------
# Output the role ARN (for GitHub Actions use)
# ------------------------------------------------------
output "tf_role_arn" {
  description = "IAM Role ARN for GitHub Actions Terraform Deployment"
  value       = aws_iam_role.tf_role.arn
}