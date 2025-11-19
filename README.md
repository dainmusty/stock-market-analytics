# working workflow
name: Stock Analyzer CI/CD

on:
  push:
    branches:
      - main
      - 'feature/**'   # Trigger CI on feature branches
  pull_request:
    branches: [main]   # Run Plan when creating PR into main
  workflow_dispatch:    # Allow manual runs

permissions:
  id-token: write
  contents: read
  pull-requests: write
  packages: write

env:
  AWS_REGION: us-east-1
  TF_VERSION: 1.9.5
  PYTHON_VERSION: '3.11'
  ROLE_NAME: data-analytics-tf-dev-role
  ARTIFACTS_BUCKET: data-analytics-dev-artifacts
  ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
  DEPLOYMENT_PATH: root_modules/env/dev

jobs:

  # ---------------------------------------------------------
  # 1) TERRAFORM PLAN (Runs on PR)
  # ---------------------------------------------------------
  Plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Plan-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform init

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform plan -no-color -out=tfplan


  # ---------------------------------------------------------
  # 2) TERRAFORM APPLY (Runs only AFTER merge → push to main)
  # ---------------------------------------------------------
  Apply:
    runs-on: ubuntu-latest
    environment: Development
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      # --- Python Setup BEFORE Uploading Lambda Artifacts ---
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install boto3 yfinance

      # =====================================================
      # PACKAGE LAMBDA PRODUCER
      # =====================================================
      - name: Package stock producer Lambda
        run: |
          zip -r stock_producer.zip \
            scripts/stock_producer.py

      # =====================================================
      # PACKAGE LAMBDA INGESTOR
      # =====================================================
      - name: Package stock ingestor Lambda
        run: |
          zip -r stock_ingestor.zip \
            scripts/stock_ingestor.py

      # =====================================================
      # UPLOAD BOTH ARTIFACTS TO S3 (after packaging)
      # =====================================================
      - name: Configure AWS credentials (assume role)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Apply-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}


      # =====================================================
      # TERRAFORM DEPLOYMENT
      # =====================================================
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform init

      - name: Terraform Apply
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform apply -auto-approve


        # =====================================================
      # UPLOAD BOTH ARTIFACTS TO S3 (after packaging)
      # =====================================================
      - name: Configure AWS credentials (assume role)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Apply-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Upload producer lambda to S3
        run: aws s3 cp stock_producer.zip s3://${{ env.ARTIFACTS_BUCKET }}/lambda/stock_producer.zip

      - name: Upload ingestor lambda to S3
        run: aws s3 cp stock_ingestor.zip s3://${{ env.ARTIFACTS_BUCKET }}/lambda/stock_ingestor.zip




# stock-market-analytics
This project implements a fully automated CI/CD pipeline using GitHub Actions and Terraform to deploy a serverless data processing architecture on AWS. The pipeline provisions all required resources (S3, Lambda, and related services), uploads the data producer package, and processes multiple stock or analytical records daily.

final workflow
name: Stock Analyzer CI/CD

on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      terraform_action:
        description: "Select the Terraform action to perform"
        required: true
        type: choice
        options:
          - "plan"
          - "apply"
          - "destroy"
      environment:
        description: "Choose the environment (for visibility only)"
        required: true
        type: choice
        options:
          - "dev"
          - "staging"
          - "production"
      skip_nochange:
        description: "Apply even if no change is reported in the plan"
        required: false
        type: boolean

permissions:
  id-token: write
  contents: read
  packages: write

env:
  AWS_REGION: us-east-1
  TF_VERSION: 1.9.5
  PYTHON_VERSION: '3.11'
  ROLE_NAME: data-analytics-tf-dev-role          # Static IAM role (already linked to GitHub OIDC)
  ARTIFACTS_BUCKET: data-analytics-dev-artifacts # Should match Terraform-deployed bucket name

jobs:
  # ---------------------- Terraform Plan ----------------------
  Plan:
    runs-on: ubuntu-latest
    if: github.event.inputs.terraform_action == 'plan'
    environment:
      name: ${{ github.event.inputs.environment }}
    outputs:
      plan-changes: ${{ steps.check-plan.outputs.changes }}

    steps:
      - name: 🧱 Checkout repository
        uses: actions/checkout@v4

      - name: ☁️ Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Plan-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🧩 Terraform Init
        run: terraform init

      - name: 🧾 Terraform Plan
        id: plan
        run: terraform plan -out=tfplan

      - name: 🔍 Check for changes
        id: check-plan
        run: |
          terraform show -no-color tfplan | grep -q "No changes" && echo "changes=false" >> $GITHUB_OUTPUT || echo "changes=true" >> $GITHUB_OUTPUT

  # ---------------------- Manual Approval ----------------------
  Approve:
    needs: Plan
    runs-on: ubuntu-latest
    if: needs.Plan.outputs.plan-changes == 'true' && github.event.inputs.terraform_action == 'apply'
    environment:
      name: ${{ github.event.inputs.environment }}
    steps:
      - name: ⏳ Await manual approval
        uses: trstringer/manual-approval@v1
        with:
          approvers: "your-github-username"
          minimum-approvals: 1
          issue-title: "Terraform Apply Approval"
          issue-body: "Approve to deploy changes to ${{ github.event.inputs.environment }}."

  # ---------------------- Terraform Apply ----------------------
  Apply:
    needs: Approve
    runs-on: ubuntu-latest
    if: github.event.inputs.terraform_action == 'apply'
    environment:
      name: ${{ github.event.inputs.environment }}

    steps:
      - name: 🧱 Checkout repository
        uses: actions/checkout@v4

      - name: ☁️ Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Apply-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🧩 Terraform Init
        run: terraform init

      - name: 🚀 Terraform Apply
        run: terraform apply -auto-approve tfplan

      # ---------------------- Python Producer Setup ----------------------
      - name: 🐍 Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: 📦 Install dependencies
        run: |
          pip install -r requirements.txt
          pip install boto3 yfinance

      - name: 📦 Package producer
        run: |
          zip -r stock_producer.zip scripts/stock_producer.py requirements.txt

      # ---------------------- Upload to S3 ----------------------
      - name: ☁️ Upload artifact to S3
        run: |
          aws s3 cp stock_producer.zip s3://${{ env.ARTIFACTS_BUCKET }}/lambda/stock_producer.zip

      # ---------------------- Optional: Run Producer Locally ----------------------
      - name: ▶️ Run stock producer (manual trigger only)
        if: github.event_name == 'workflow_dispatch'
        run: python scripts/stock_producer.py

  # ---------------------- Terraform Destroy ----------------------
  Destroy:
    runs-on: ubuntu-latest
    if: github.event.inputs.terraform_action == 'destroy'
    environment:
      name: ${{ github.event.inputs.environment }}
    steps:
      - name: 🧱 Checkout repository
        uses: actions/checkout@v4

      - name: ☁️ Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Destroy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🧩 Terraform Init
        run: terraform init

      - name: 💣 Terraform Destroy
        run: terraform destroy -auto-approve


when i hit pull request, got the info below
Choose different branches or forks above to discuss and review changes. Learn about pull requests

This message means:
❌ There are no changes between your current branch and main.
So GitHub cannot create a pull request.
You will only see this message when:


You are already on the main branch, OR


You have not created a separate feature branch with changes, OR


The code was pushed directly into main so GitHub sees nothing to compare.



✅ Why this happened
Your workflow triggers on:
push:
  branches:
    - main

So when you pushed your Terraform code, it went straight to main.
Since PRs are created from another branch → into main, GitHub says:

“Choose different branches …”
(because you are comparing main with main)


🚀 How to fix it (best practice)
Step 1 — Create a new branch
On your machine:
git checkout -b feature/terraform-update

Commit something OR move your config files into this branch:
git add .
git commit -m "Move Terraform code to feature branch"
git push origin feature/terraform-update

Step 2 — Create a Pull Request
Now GitHub will show:

Compare: feature/terraform-update → main

And PR will be created successfully.
Then:


Terraform Plan will run automatically


Plan comment will appear on the PR


After you review, merge the PR


Terraform Apply will run (with manual approval)


This is the correct professional workflow.

🧠 Important: Your current workflow does not support “PR plan” because your Terraform code is already in main
Once you create the feature branch and PR, everything works normally.

If you want, I can:
✔️ Modify the workflow so you never push directly to main
✔️ Add a rule that forces PR reviews before merging
✔️ Add branch protections
✔️ Add automatic plan comments on PRs
Just say "set it up" and I will configure everything properly.