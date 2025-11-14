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
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.github_repo_project_link
        }
      }
    }
  ]
})
  tags = var.tf_role_tags
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
        Action = var.tf_role_permissions
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


