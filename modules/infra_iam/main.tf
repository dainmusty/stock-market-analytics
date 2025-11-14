data "aws_caller_identity" "current" {}

# Fetch the existing GitHub OIDC provider (you already have it in your account)
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}


# IAM Role for Lambda Ingest Function
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_ingest" {
  name               = var.lambda_ingest_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Lambda inline policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = var.lambda_policy_name
  role = aws_iam_role.lambda_ingest.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs access
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/*"
      },

      # S3 access
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          var.raw_bucket_arn,
          "${var.raw_bucket_arn}/*",
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*"
        ]
      },

      # DynamoDB access
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ],
        Resource = var.dynamodb_table_arn
      },

      # Kinesis stream access
      {
        Effect = "Allow",
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ],
        Resource = var.kinesis_stream_arn
      }
    ]
  })
}


# IAM Role and Policy for Lambda Stock Producer function
resource "aws_iam_role" "lambda_producer" {
  name = var.lambda_producer_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_producer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis" {
  role       = aws_iam_role.lambda_producer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}


# IAM Role for Glue job
data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "glue_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      "${var.raw_bucket_arn}",
      "${var.raw_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "glue:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "glue_policy" {
  name   = var.glue_policy_name
  policy = data.aws_iam_policy_document.glue_policy.json
}

resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_exec.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

resource "aws_iam_role" "glue_exec" {
  name               = var.glue_role_name
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

