variable "glue_database_name" { type = string }
variable "athena_results_bucket_name" { type = string }
variable "tags" { 
  type = map(string) 
  default = {} 
  }
