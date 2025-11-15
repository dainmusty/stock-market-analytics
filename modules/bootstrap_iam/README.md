but the arn has the account id and even though i deployed it separately, i intend to push the entire project code to git which will expose the id. what do you think? should i remove the oidc tf role deployment from the project code? what's best practice?

✅ Short Answer (best practice)
YES — remove the GitHub OIDC Role (bootstrap IAM role) from your Terraform project.

That role should NOT live inside the same project that uses it.

It should be:

created ONCE manually or in a separate bootstrap repo,

stored outside the main infrastructure code,

and never destroyed automatically.

This is how all professional Terraform setups are done.

🧠 Why? (Industry Best Practice Reasoning)
1️⃣ Account ID is NOT sensitive

Your AWS account ID is not a secret.
AWS says this officially.

Leaking it does not expose your AWS environment.

So having it in GitHub is perfectly fine.

But this is not the reason we split the bootstrapping role.

2️⃣ Terraform cannot safely manage the role it needs to assume

Your Terraform code is executed using the OIDC role.

If Terraform also manages that same role:

❌ You can delete the role by accident

…and lock yourself out of CI/CD.

❌ A failed apply could corrupt the trust policy

…and break deployments instantly.

❌ Destroying the environment could delete the GitHub OIDC trust

…and your entire pipeline stops working.

This is extremely dangerous.

3️⃣ Bootstrap resources should live in a separate state

This is the official AWS + HashiCorp recommendation:
resources that allow Terraform to run should NOT be managed by the same Terraform.

These include:

Bootstrap Resource	Should be in project?
GitHub OIDC Provider	❌ NO
Terraform Execution Role	❌ NO
Backend S3 Bucket	❌ NO
Backend DynamoDB Table	❌ NO

These must be created in a permanent, manually-controlled IAM bootstrap stack.

🏗️ Typical Professional Architecture
✔️ Repo 1 → bootstrap-aws-account

Contains:

S3 backend bucket

DynamoDB lock table

GitHub OIDC provider

Terraform execution IAM role

(Optional) audit logging roles

Applied ONCE manually by an admin.

✔️ Repo 2 → your actual project (stock-market-analytics)

Contains:

S3 bucket for raw data

Kinesis

Glue

Lambda

DynamoDB

Athena

Everything else

Uses the bootstrap IAM role but does not manage it.

📌 Your case right now

You have this inside your repo:

resource "aws_iam_role" "tf_role"


This should NOT be part of the project.
It should be moved to a permanent standalone bootstrap folder that is NEVER deployed from GitHub Actions.

🌟 Recommended Fix for You
🔥 Remove all this from your repo:

bootstrap_iam/

oidc_tf_role/

Anything that creates:

GitHub OpenID Connect Provider

Terraform execution role

Permissions for GitHub Actions

🔥 Keep only:

Kinesis

Lambda

DynamoDB

S3 buckets

Glue

Athena

❓ About Account ID exposure

Again:

✔️ Account ID is public and NOT a secret

AWS explicitly states this: it is not considered sensitive information.
Even AWS ARNs in documentation always include account IDs.

The only sensitive parts are:

IAM policies granting unwanted permissions

Access keys

Secrets

KMS key material

Private data

Not the account ID.

🧭 Conclusion
✔️ Best practice = remove the OIDC/TF role from your project
✔️ Maintain it separately in a bootstrap folder (never destroyed)
✔️ Your repo will be cleaner, safer, and fully aligned with industry standards
✔️ Account ID exposure is NOT a problem