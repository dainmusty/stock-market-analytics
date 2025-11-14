variable "lambda_policy_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "lambda_ingest_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "raw_bucket_arn" {
  description = "ARN of the raw data S3 bucket"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for processed data"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "glue_role_name" {
  description = "Name of the Glue execution role"
  type        = string
  default     = "glue-exec-role"
}

variable "github_repo_branch_link" {
  description = "GitHub repository and branch link for OIDC trust, e.g., 'repo:username/repo-name:ref:refs/heads/main'"
  type        = string
}

variable "tf_role_name" {
  description = "Name of the IAM Role for GitHub Actions Terraform Deployment"
  type        = string
  default     = "tf_role"
}

# IAM Role and Policy for Lambda Stock Producer
variable "lambda_producer_role_name" {
  type = string
}