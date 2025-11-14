variable "env" { type = string }
variable "artifacts_bucket_name" { type = string }
variable "artifacts_key" { type = string }
variable "lambda_role_arn" { type = string }
variable "raw_bucket_name" { type = string }
variable "ddb_table_name" { type = string }
variable "kinesis_stream_arn" { type = string }
variable "tags" { 
  type = map(string) 
  default = {}
  }

variable "function_name" {
  
}
