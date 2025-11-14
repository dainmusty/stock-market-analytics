output "raw_bucket_name" {
  value = aws_s3_bucket.raw.bucket
}

output "raw_bucket_arn" {
  value = aws_s3_bucket.raw.arn
}

output "athena_results_bucket_name" {
  value = aws_s3_bucket.athena_results.bucket
}

output "athena_results_bucket_arn" {
  value = aws_s3_bucket.athena_results.arn
}

output "artifacts_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}
