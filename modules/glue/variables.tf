variable "env" { type = string }
variable "raw_bucket_name" { type = string }
variable "glue_role_arn" { type = string }
variable "crawler_schedule" {
  type    = string
  default = "cron(0/15 * * * ? *)"
}
variable "tags" { 
  type = map(string) 
  default = {} 
  }
