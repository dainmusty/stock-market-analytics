resource "aws_s3_bucket" "raw" {
  bucket = var.raw_data_bucket_name

  tags = merge(var.tags, {
    Name = "stock-pipeline-raw"
    Purpose = "Raw ingestion data"
  })
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = var.athena_results_bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name = "stock-pipeline-results"
    Purpose = "Athena query results"
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name
  

  tags = merge(var.tags, {
    Name = "stock-pipeline-artifacts"
    Purpose = "Lambda/Glue artifacts"
  })
}
