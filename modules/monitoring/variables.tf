variable "env" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "alert_email" {
  description = "Email address to subscribe to SNS alerts"
  type        = string
}

variable "tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}
