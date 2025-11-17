provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  project_name = "data-analytics"
  env          = "dev"
  
}

module "s3" {
  source = "../../../modules/s3"

  raw_data_bucket_name       = "${local.project_name}-${local.env}-raw"
  athena_results_bucket_name = "${local.project_name}-${local.env}-athena-results"
  artifacts_bucket_name      = "${local.project_name}-${local.env}-artifacts"
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}


module "monitoring" {
  source = "../../../modules/monitoring"

  env                  = local.env
  lambda_function_name = module.lambda_ingest.lambda_function_name
  alert_email          = "alerts@example.com"
  tags = {
    Environment = "dev"
    Project     = local.project_name
  }
}


module "lambda_ingest" {
  source = "../../../modules/lambda_ingest"

  env                   = local.env
  artifacts_bucket_name = module.s3.artifacts_bucket_name
  artifacts_key         = "lambda/function.zip"
  lambda_role_arn       = module.iam.lambda_ingest_role_arn
  raw_bucket_name       = module.s3.raw_bucket_name
  ddb_table_name        = module.dynamo.table_name
  kinesis_stream_arn    = module.kinesis.kinesis_stream_arn
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
  function_name = "${local.env}-stock-ingest"
}


module "lambda_producer" {
  source = "../../../modules/lambda_producer"

  artifacts_bucket         = module.s3.artifacts_bucket_name
  lambda_producer_role_arn = module.iam.lambda_producer_role_arn
  stream_name              = module.kinesis.kinesis_stream_name
  function_name            = "${local.env}-stock-producer"
  event_rule_name          = "${local.env}-invoke-stock-producer"

  lambda_producer_role_basic_attachment   = module.iam.lambda_producer_role_basic_attachment
  lambda_producer_role_kinesis_attachment = module.iam.lambda_producer_role_kinesis_attachment
  lambda_handler                          = "stock_producer.main" # ⚙️ Default for dev; change to stock_producer.lambda_handler for prod
  region                                  = "us-east-1"
  lambda_memory                           = 256
  lambda_timeout                          = 900
  schedule_expression                     = "rate(1 minute)"
  artifacts_key                           = "lambda/stock_producer.zip"
  lambda_runtime                          = "python3.11"

  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}


module "kinesis" {
  source = "../../../modules/kinesis"

  env                 = local.env
  kinesis_stream_name = "${local.env}-stock-stream"
  shard_count         = 1
  retention_hours     = 24
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "iam" {
  source = "../../../modules/infra_iam"

  # general variables
  region                  = "us-east-1"
  account_id              = data.aws_caller_identity.current.account_id

  # lambda-ingest and producer variables
  lambda_policy_name      = "${local.env}-lambda-ingest-policy"
  lambda_ingest_role_name   = "${local.env}-lambda-ingest-exec-role"
  lambda_producer_role_name = "lambda-producer-exec-${local.env}"
  
  # glue variables
  glue_role_name            = "${local.env}-glue-exec-role"
  glue_policy_name          = "${local.env}-glue-policy"

  # Bucket and table ARNs variables
  raw_bucket_arn          = module.s3.raw_bucket_arn
  artifacts_bucket_arn    = module.s3.artifacts_bucket_arn
  dynamodb_table_arn      = module.dynamo.table_arn
  kinesis_stream_arn = module.kinesis.kinesis_stream_arn
}



module "glue" {
  source = "../../../modules/glue"

  env              = local.env
  raw_bucket_name  = module.s3.raw_bucket_name
  glue_role_arn    = module.iam.glue_role_arn
  crawler_schedule = "cron(0/15 * * * ? *)"
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "athena" {
  source = "../../../modules/athena"

  glue_database_name         = "analytics_db"
  athena_results_bucket_name = module.s3.athena_results_bucket_name
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "dynamo" {
  source = "../../../modules/dynamo"

  env = local.env
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}


