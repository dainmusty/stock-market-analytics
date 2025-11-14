output "tf_role_arn" {
  description = "IAM Role ARN for GitHub Actions Terraform Deployment"
  value       = aws_iam_role.tf_role.arn
}