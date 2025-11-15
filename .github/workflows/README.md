🏗️ Visual Architecture Diagram
           ┌─────────────────────────────────────────────┐
           │             GitHub Actions CI/CD             │
           │---------------------------------------------│
           │  1. Zip Python code                         │
           │  2. Upload ZIP to S3 Artifacts bucket        │
           │  3. Run Terraform apply                     │
           └─────────────────────────────────────────────┘
                               │
                               ▼
           ┌─────────────────────────────────────────────┐
           │          Lambda Producer (stock_producer)   │
           │---------------------------------------------│
           │  - Reads stock data via yfinance            │
           │  - Sends JSON records to Kinesis Stream     │
           └─────────────────────────────────────────────┘
                               │
                               ▼
           ┌─────────────────────────────────────────────┐
           │             Kinesis Data Stream              │
           │---------------------------------------------│
           │  - Buffers incoming stock data               │
           │  - Triggers Lambda Ingest                   │
           └─────────────────────────────────────────────┘
                               │
                               ▼
           ┌─────────────────────────────────────────────┐
           │           Lambda Ingest (stock_ingest)      │
           │---------------------------------------------│
           │  - Reads records from Kinesis               │
           │  - Writes raw JSON to S3 Raw bucket         │
           └─────────────────────────────────────────────┘
                               │
                               ▼
           ┌─────────────────────────────────────────────┐
           │                  AWS Glue                   │
           │---------------------------------------------│
           │  - Crawls Raw S3 bucket                     │
           │  - Creates Glue Data Catalog                │
           └─────────────────────────────────────────────┘
                               │
                               ▼
           ┌─────────────────────────────────────────────┐
           │                   Athena                    │
           │---------------------------------------------│
           │  - Queries data via SQL                     │
           │  - Stores results in Athena_Results bucket  │
           └─────────────────────────────────────────────┘

🧩 Flow of That Section in the Pipeline

1️⃣ Package the code

zip -r stock_producer.zip scripts/stock_producer.py requirements.txt


2️⃣ Upload to S3 artifacts bucket

aws s3 cp stock_producer.zip s3://data-analytics-dev-artifacts/lambda/stock_producer.zip


3️⃣ Terraform deploys the Lambda
Terraform uses those values:

s3_bucket = var.artifacts_bucket
s3_key    = "lambda/stock_producer.zip"


and tells AWS Lambda to create or update the function using that package.

🧠 So Conceptually
Step	Purpose	Example
GitHub Actions	Uploads the zip to S3	s3://data-analytics-dev-artifacts/lambda/stock_producer.zip
Terraform	Deploys Lambda using that S3 object	Lambda points to the S3 object for its code
Lambda Producer	Runs and sends stock data to Kinesis	kinesis:PutRecord()
Lambda Ingest	Reads from Kinesis, writes to S3 raw bucket	s3:PutObject()
🏗️ Visual Architecture Diagram

The Big Picture: Two Different “S3” Roles Here
Purpose	What’s Stored	Why It’s in S3
Lambda deployment package	stock_producer.zip (your code)	So AWS Lambda can fetch and deploy your function
Data storage	Raw data from Kinesis → S3 bucket (like raw-data-bucket)	To store stock data for Glue + Athena processing

So yes — the stock data goes into Kinesis, and Lambda_ingest writes that data into your raw-data S3 bucket.
But separately, your Lambda code itself (the zipped Python script) must live in an artifacts S3 bucket so AWS can deploy it.

That’s what this line is for:

s3_key = var.artifacts_key  # e.g. "lambda/stock_producer.zip"


It points to the code artifact, not your business data.

🧩 The End-to-End Flow (you have two Lambdas)
1️⃣ Lambda Producer (lambda_producer)
Step	Action
1	Triggered manually (in dev) or by CloudWatch schedule (in prod)
2	Fetches stock prices from Yahoo Finance using yfinance
3	Sends JSON data to Kinesis stream using put_record()
✅	The function code (zip) itself lives in S3 artifacts bucket, so Lambda can fetch it
2️⃣ Kinesis → Lambda Ingest (lambda_ingest)
Step	Action
1	Kinesis automatically triggers this consumer Lambda
2	The Lambda reads new Kinesis records
3	Writes those records to your raw S3 bucket (s3:PutObject)
✅	This Lambda code also lives in your artifacts S3 bucket (deployed by Terraform)
3️⃣ Downstream ETL
Component	Action
Glue	Crawls the raw S3 bucket to catalog schema
Athena	Runs SQL queries on top of the Glue catalog
Results Bucket	Stores Athena query outputs (e.g., athena_results/)
🏗️ So in Terraform:

You have two S3 buckets with different purposes:

Bucket	Example	Used For
my-artifacts-bucket	lambda/stock_producer.zip	Lambda deployment code
my-raw-bucket	raw-data/YYYY/MM/DD/	Actual stock data (from Kinesis consumer)
my-athena-results	athena-results/	Athena query output
✅ Summary

The line

s3_key = var.artifacts_key


refers to where Lambda fetches your zipped Python code from — not the data it processes.

Your data still goes:
Producer Lambda → Kinesis → Ingest Lambda → Raw S3 → Glue → Athena.
Structure
Full Integration: Python → Terraform → Lambda → Kinesis

🧭 Context — Two Lambda Functions, Two Different Roles
LambdaPurposeTrigger TypeData DirectionProducer (new one I gave)Fetches real-time stock data from Yahoo Finance and pushes it to KinesisEventBridge schedule (every minute)Outbound → to KinesisIngest (the one you just showed)Reads data from Kinesis and writes it to DynamoDB / S3 / Data LakeKinesis stream triggerInbound ← from Kinesis

🧩 So in your system:


stock_producer Lambda (Event-driven, Push)


Automatically triggered every minute by EventBridge.


Fetches stock data using yfinance.


Sends each stock record into Kinesis Data Stream (stock-stream-dev).



This is what replaces your local Python script loop — fully serverless now.



stock_ingest Lambda (Stream trigger, Process)


Triggered by Kinesis events whenever data arrives.


Processes or stores data into:


S3 (raw bucket) for archiving, or


DynamoDB for quick analytics, or


Firehose for transformation and delivery.







🧠 Think of it like this flow
EventBridge (1-min schedule)
          ↓
stock_producer Lambda (Fetch + Push)
          ↓
   Kinesis Stream (stock-stream-dev)
          ↓
stock_ingest Lambda (Consume + Store)
          ↓
    S3 / DynamoDB / Redshift


🧱 Terraform Recap
You’ll end up with two Lambda modules (can live in same repo):
Module 1 — lambda_producer (the new one)


Deploys stock_producer.py Lambda


Scheduled via CloudWatch/EventBridge


Has permissions for kinesis:PutRecord


Module 2 — lambda_ingest (your existing one)


Triggered by Kinesis stream events


Has permissions for kinesis:GetRecords + s3:PutObject or dynamodb:PutItem



✅ What to Do Now
Since your Python script is the producer, go ahead and:


Use the Terraform producer setup I gave (the one with EventBridge)


Keep your existing ingest Lambda Terraform block (it’s correct)


Both will work together to form the complete ingestion pipeline



Would you like me to show you how to structure the Terraform folders so you have:
modules/
  lambda_producer/
  lambda_ingest/

with clear variable definitions and outputs for both?
That way your infrastructure stays modular and easy to expand later (e.g., adding Firehose or S3 transformations).


# Earlier workflow
name: Stock Analyzer CI/CD

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    env:
      AWS_REGION: us-east-1
      TF_VERSION: 1.9.5
      PYTHON_VERSION: '3.11'
      ROLE_NAME: data-analytics-tf-dev-role                      # IAM role name to assume (already linked to GitHub OIDC)
      ARTIFACTS_BUCKET: data-analytics-dev-artifacts   # should match Terraform var

    steps:
      # ---------------------- Checkout ----------------------
      - name: 🧱 Checkout repository
        uses: actions/checkout@v4

      # ---------------------- Terraform Setup ----------------------
      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      # ---------------------- Get AWS Account ID ----------------------
      - name: 🔍 Retrieve AWS Account ID dynamically
        id: aws-id
        run: |
          echo "Fetching AWS account ID..."
          account_id=$(aws sts get-caller-identity --query Account --output text --region ${{ env.AWS_REGION }} || echo "unknown")
          echo "account_id=$account_id" >> $GITHUB_ENV

      # ---------------------- Configure AWS Credentials via OIDC ----------------------
      - name: ☁️ Configure AWS credentials (OIDC Assume Role)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-StockAnalyzer-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      # ---------------------- Terraform Steps ----------------------
      - name: 🧩 Terraform Init
        run: terraform init

      - name: ✅ Terraform Validate
        run: terraform validate

      - name: 📜 Terraform Plan
        run: terraform plan -out=tfplan

      - name: 🚀 Terraform Apply
        if: github.ref == 'refs/heads/main'
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



i don't see where exactly you have declared this variable - ${{env.accound_id}}. the block below suggest that the acc id is appended to  $GITHUB_ENV and not ${{env.accound_id}}. so at which point does the acc id get to replaced in this line role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
 - name: 🔍 Retrieve AWS Account ID dynamically
        id: aws-id
        run: |
          echo "Fetching AWS account ID..."
          account_id=$(aws sts get-caller-identity --query Account --output text --region ${{ env.AWS_REGION }} || echo "unknown")
          echo "account_id=$account_id" >> $GITHUB_ENV

      # ---------------------- Configure AWS Credentials via OIDC ----------------------
      - name: ☁️ Configure AWS credentials (OIDC Assume Role)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.account_id }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-StockAnalyzer-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

and its not part of the env variables declared at the beginning of the workflow
env:
      AWS_REGION: us-east-1
      TF_VERSION: 1.9.5
      PYTHON_VERSION: '3.11'
      ROLE_NAME: data-analytics-tf-dev-role                      # IAM role name to assume (already linked to GitHub OIDC)
      ARTIFACTS_BUCKET: data-analytics-dev-artifacts   # should match Terraform var



What does the “Check for changes” job do?

This step:

- name: 🔍 Check for changes
  id: check-plan
  run: |
    terraform show -no-color tfplan | grep -q "No changes" && echo "changes=false" >> $GITHUB_OUTPUT || echo "changes=true" >> $GITHUB_OUTPUT

✔ Purpose

It looks inside the saved tfplan file and checks whether Terraform reported:

No changes. Your infrastructure matches the configuration.


Then it sets an output (true/false) that the Approve job uses.

✔ Why it exists

This allows the pipeline to skip manual approval when there are no changes.

Without this step:

The apply job will require approval even if Terraform is doing nothing.

✔ Does anything depend on it?

YES → this step controls whether the Approve job runs.

This block in the workflow:

if: needs.Plan.outputs.plan-changes == 'true'


Uses the value set by check-plan.

❓ Is this job required?
No — you can remove it if:

✔ You want a simpler pipeline
✔ You always want manual approval before apply
OR
✔ You remove the approval stage altogether

❗ If you remove check-plan → You MUST do one of these:
Option A (simple): Remove the Approve job completely

Then Apply will always run.

Option B: Keep approval but ALWAYS force approval

Change this:

needs.Plan.outputs.plan-changes == 'true'


to:

true


Example:

if: github.event.inputs.terraform_action == 'apply'


Would you like me to now show how to automatically switch the handler (main vs lambda_handler) in CI/CD depending on environment (dev vs prod)?

 ${{ secrets.AWS_IAM_ROLE_ARN }}

  name: Setup Terraform v1.11.1
        uses: hashicorp/setup-Terraform@v1
        with:
          terraform_version: 1.11.1
          terraform_wrapper: false

      - name: Setup Terraform version
        run: terraform --version

      - name: Setup Terraform wrapper path
        run: which terraform


#final working worklow without out approval
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
  ROLE_NAME: data-analytics-tf-dev-role          # Existing terraform role for data-analytics project. Update per environment as needed.
  ARTIFACTS_BUCKET: data-analytics-dev-artifacts # Should match Terraform-deployed bucket name
  ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
  DEPLOYMENT_PATH: root_modules/env/dev


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
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Plan-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}


      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🧩 Terraform Init
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform init 

      - name: 🧾 Terraform Plan
        id: plan
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform plan -out=tfplan

      - name: 🔍 Check for changes
        working-directory: ${{ env.DEPLOYMENT_PATH }}
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
          
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Apply-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}


      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🚀 Terraform Apply
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform apply -auto-approve

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
          
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Destroy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}


      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 💣 Terraform Destroy
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform destroy -auto-approve


Want me to add?

✅ “Skip apply if no changes unless skip_nochange = true”
✅ Slack notification on approval
✅ PR comments with the plan output
✅ Artifact uploads for tfplan files

final workflow with approval
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
  ROLE_NAME: data-analytics-tf-dev-role
  ARTIFACTS_BUCKET: data-analytics-dev-artifacts
  ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
  DEPLOYMENT_PATH: root_modules/env/dev


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
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Plan-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🧩 Terraform Init
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform init 

      - name: 🧾 Terraform Plan
        id: plan
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform plan -out=tfplan

      - name: 🔍 Check for changes
        working-directory: ${{ env.DEPLOYMENT_PATH }}
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
      url: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
    steps:
      - name: ⏳ Await manual approval
        uses: trstringer/manual-approval@v1
        with:
          approvers: "dainmusty"
          minimum-approvals: 1
          issue-title: "Terraform Apply Approval Required"
          issue-body: "Approve to deploy Terraform changes to **${{ github.event.inputs.environment }}**."


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
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Apply-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🚀 Terraform Apply
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform apply -auto-approve

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
          role-to-assume: arn:aws:iam::${{ env.ACCOUNT_ID }}:role/${{ env.ROLE_NAME }}
          role-session-name: GitHubActions-Terraform-Destroy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ⚙️ Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 💣 Terraform Destroy
        working-directory: ${{ env.DEPLOYMENT_PATH }}
        run: terraform destroy -auto-approve



✅ 1. The workflow will NOT automatically create a Pull Request.

Your current setup supports running Terraform plan on:

A PR created by you

A manual workflow_dispatch plan

(optionally) plan from a push to main — but this is typically not preferred

But nothing in the workflow automatically creates a PR for you.

So yes — you must manually create the pull request if your intention is:

PR → Plan → PR Comment → Merge → Apply

This is the standard best-practice flow.