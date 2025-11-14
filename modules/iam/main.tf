# ======================================================
# GitHub OIDC Role for Terraform Deployments (tf_role)
# ======================================================

data "aws_caller_identity" "current" {}

# Fetch the existing GitHub OIDC provider (you already have it in your account)
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# ------------------------------------------------------
# IAM Role for GitHub Actions Terraform Deployment
# ------------------------------------------------------
resource "aws_iam_role" "tf_role" {
  name = var.tf_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Must match your GitHub repo and branch
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" = var.github_repo_branch_link
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "GitHub Actions Terraform Deployment Role"
    ManagedBy = "Terraform"
  }
}

# ------------------------------------------------------
# Least-privilege IAM Policy for Terraform
# ------------------------------------------------------
resource "aws_iam_policy" "terraform_least_privilege" {
  name = "TerraformLeastPrivilegePolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "TerraformCoreResources",
        Effect = "Allow",
        Action = [
          "s3:*",
          "dynamodb:*",
          "kinesis:*",
          "lambda:*",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole",
          "cloudwatch:*",
          "logs:*",
          "glue:*",
          "athena:*",
          "sns:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------
# Attach the policy to the tf_role
# ------------------------------------------------------
resource "aws_iam_role_policy_attachment" "tf_role_policy_attach" {
  role       = aws_iam_role.tf_role.name
  policy_arn = aws_iam_policy.terraform_least_privilege.arn
}





data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for Lambda Ingest Function
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
      }
    ]
  })
}


data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_exec" {
  name               = var.glue_role_name
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}


# IAM Role and Policy for Lambda Stock Producer
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

