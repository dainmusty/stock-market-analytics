variable "raw_data_bucket_name" {
  description = "name of raw data bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all buckets"
  type        = map(string)
  default     = {}
}

variable "athena_results_bucket_name" {
  description = "name of ahtena results data bucket"
  type        = string
}


variable "artifacts_bucket_name" {
  description = "name of artifacts data bucket"
  type        = string
}