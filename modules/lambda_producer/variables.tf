variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "artifacts_bucket" {
  description = "S3 bucket containing the Lambda package"
  type        = string
}

variable "artifacts_key" {
  description = "S3 key for the Lambda ZIP artifact"
  type        = string
  
}

variable "lambda_handler" {
  description = "Lambda handler (use .main for dev, .lambda_handler for prod)"
  type        = string
  default     = "stock_producer.main"  # ⚙️ Default for dev; change to stock_producer.lambda_handler for prod
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
   
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
   
}

variable "lambda_memory" {
  description = "Lambda memory size in MB"
  type        = number
  
}

variable "lambda_producer_role_arn" {
  description = "IAM role ARN for Lambda producer"
  type        = string
}

variable "lambda_producer_role_basic_attachment" {
  description = "Basic execution policy attachment"
}

variable "lambda_producer_role_kinesis_attachment" {
  description = "Kinesis execution policy attachment"
}

variable "stream_name" {
  description = "Kinesis stream name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
   
}

variable "event_rule_name" {
  description = "Name of the CloudWatch event rule"
  type        = string
   
}

variable "schedule_expression" {
  description = "CloudWatch schedule expression"
  type        = string
  
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
   
}
