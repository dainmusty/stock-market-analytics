# terraform {
#   backend "s3" {
#     bucket         = "mustydain"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     use_lockfile = true   # optional, uncomment if using state locking, e.g. with DynamoDB but the current format.
#     # Native s3 locking!
#   }
# }
