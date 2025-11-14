provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  project_name = "data-analytics"
  env          = "dev"
}

module "s3" {
  source = "../../modules/s3"

  raw_data_bucket_name       = "${local.project_name}-${local.env}-raw"
  athena_results_bucket_name = "${local.project_name}-${local.env}-athena-results"
  artifacts_bucket_name      = "${local.project_name}-${local.env}-artifacts"
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}



module "rds" {
  source = "../../modules/rds"

  db_engine               = "postgres"
  db_engine_version       = "13"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "appdb"
  username                = module.ssm.db_access_parameter_value
  password                = module.ssm.db_secret_parameter_value
  vpc_security_group_ids  = []
  multi_az                = false
  storage_type            = "gp2"
  backup_retention_period = 7
  identifier              = "dev-db"
  skip_final_snapshot     = true
  publicly_accessible     = false
  db_tags                 = { Environment = "dev" }
  env                     = local.env
  db_subnet_group_name    = "dev-db-subnet-group"
  subnet_ids              = []

  # ElastiCache/Cache related
  node_type       = "cache.t3.micro"
  num_cache_nodes = 2
  cache_sg_ids    = []
}

module "monitoring" {
  source = "../../modules/monitoring"

  env                  = local.env
  lambda_function_name = module.lambda_ingest.lambda_function_name
  alert_email          = "alerts@example.com"
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "lambda_ingest" {
  source = "../../modules/lambda_ingest"

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
  source = "../../modules/lambda_producer"

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
  source = "../../modules/kinesis"

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
  source = "../../modules/iam"

  tf_role_name            = "${local.project_name}-tf-${local.env}-role"
  lambda_policy_name      = "${local.env}-lambda-ingest-policy"
  raw_bucket_arn          = module.s3.raw_bucket_arn
  artifacts_bucket_arn    = module.s3.artifacts_bucket_arn
  dynamodb_table_arn      = module.dynamo.table_arn
  region                  = "us-east-1"
  account_id              = data.aws_caller_identity.current.account_id
  github_repo_branch_link = "repo:dainmusty/stock-market-analytics:*" # Update with the correct repo/branch


  lambda_ingest_role_name   = "${local.env}-lambda-ingest-exec-role"
  lambda_producer_role_name = "lambda-producer-exec-${local.env}"
}



module "glue" {
  source = "../../modules/glue"

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
  source = "../../modules/athena"

  glue_database_name         = "analytics_db"
  athena_results_bucket_name = module.s3.athena_results_bucket_name
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "dynamo" {
  source = "../../modules/dynamo"

  env = local.env
  tags = {
    Environment = "dev"
    Project     = "data-analytics"
  }
}

module "ssm" {
  source                   = "../../modules/ssm"
  db_access_parameter_name = "/db/access"
  db_secret_parameter_name = "/db/secure/access"
  key_path_parameter_name  = "/kp/path"
  key_name_parameter_name  = "/kp/name"

}


