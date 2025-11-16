locals {
  env = "dev"
  project_name = "data-analytics"
}

module "bootstrap_iam" {
  source = "../../modules/bootstrap_iam"

  tf_role_name = "${local.project_name}-tf-${local.env}-role"

  tf_role_permissions = [
    # --- Existing Permissions ---
    "s3:*",
    "dynamodb:*",
    "kinesis:*",
    "lambda:*",
    "iam:GetRole",
    "iam:ListRoles",
    "iam:PassRole",
    "iam:GetOpenIDConnectProvider",
    "cloudwatch:*",
    "logs:*",
    "glue:*",
    "athena:*",
    "sns:*",

    # --- NEW: Required for Terraform to create IAM resources ---
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:UpdateRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:DeleteRolePolicy",
    "iam:CreatePolicy",
    "iam:CreatePolicyVersion",
    "iam:DeletePolicyVersion",
    "iam:GetPolicy",
    "iam:GetPolicyVersion",
    "iam:ListPolicyVersions",
    "iam:TagRole",

    # --- NEW: Required for EventBridge rules for Lambda triggers ---
    "events:PutRule",
    "events:DeleteRule",
    "events:PutTargets",
    "events:RemoveTargets"
  ]

  github_repo_project_link = "repo:dainmusty/stock-market-analytics:*"

  tf_role_tags = {
    Purpose  = "GitHub Actions Terraform Deployment Role"
    ManagedBy = "Terraform"
  }
}


