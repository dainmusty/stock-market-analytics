variable "github_repo_project_link" {
  description = "GitHub repository and branch link for OIDC trust, e.g., 'repo:username/repo-name:ref:refs/heads/main'"
  type        = string
}

variable "tf_role_name" {
  description = "Name of the IAM Role for GitHub Actions Terraform Deployment"
  type        = string
  default     = "tf_role"
}

variable "tf_role_tags" {
  type = map(string)
}

variable "tf_role_permissions" {
  description = "List of AWS IAM actions allowed for Terraform deployments."
  type        = list(string)
}