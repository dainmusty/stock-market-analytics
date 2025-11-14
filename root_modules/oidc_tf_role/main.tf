locals {
  env = "dev"
  project_name = "data-analytics"
}

module "bootstrap_iam" {
  source = "../../modules/bootstrap_iam"

  tf_role_name            = "${local.project_name}-tf-${local.env}-role"
  tf_role_permissions = [
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
        ]
   
  
  github_repo_project_link = "repo:dainmusty/stock-market-analytics:*" # Update with the correct repo/branch

  tf_role_tags = {
    Purpose = "GitHub Actions Terraform Deployment Role"
    ManagedBy = "Terraform"
  }
  
}

