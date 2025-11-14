Here’s a quick validation checklist:

✅ Check	Explanation
s3_bucket + s3_key	Correct — your GitHub Actions uploads stock_producer.zip to lambda/ inside the artifacts bucket.
handler = "stock_producer.main"	Perfect — this matches the Python file name (stock_producer.py) and the main() function (which Lambda calls through lambda_handler() if you prefer). If your entry function is lambda_handler, use "stock_producer.lambda_handler".
runtime = "python3.11"	Modern and correct.
role = var.lambda_producer_role_arn	Good practice — keeps IAM separation clean.
timeout = 900 (15 min)	Generous and safe for API polling workloads.
environment { STREAM_NAME, REGION }	Exactly what the Python script expects via os.getenv().
depends_on	Ensures Lambda creation waits for IAM role attachments. Excellent!
🧩 Small optional adjustment

If your Lambda handler function inside the script is:

def lambda_handler(event, context):


then your handler line in Terraform should be:

handler = "stock_producer.lambda_handler"


If instead you want it to execute the infinite main() loop (e.g., for testing or when invoked manually), then keep:

handler = "stock_producer.main"


For AWS-managed scheduled invocations (e.g., via EventBridge every minute), the lambda_handler entry point is usually better, since it runs once per event trigger — not indefinitely.


to make sure i understand you, if i want the execution to be continuous and non-ending, then i should keep it as ".main" but it i want to be per manual trigger, then i should change it to ".lambda_handler" correct?

How AWS Lambda Works

Lambda does not run continuously by default.
It is event-driven, meaning AWS invokes it in response to something (like an EventBridge schedule, API Gateway call, Kinesis event, etc.).

| Scenario                                          | Lambda Handler                              | Execution Behavior                                                                                                                                                                                   | Suitable For             |
| ------------------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **Continuous execution** (runs forever in a loop) | `handler = "stock_producer.main"`           | The code runs indefinitely *once invoked*. You must invoke it manually (CLI, test event, or workflow). AWS **will stop it after 15 minutes**, since Lambda has a **maximum timeout of 900 seconds**. | Temporary / testing only |
| **Triggered execution** (runs once per schedule)  | `handler = "stock_producer.lambda_handler"` | The code executes once for each scheduled trigger (e.g. every minute via EventBridge). Each run fetches and pushes data, then exits. AWS will re-invoke it automatically.                            | ✅ **Production use**     |


erraform variable + condition logic so that the handler automatically switches between .main (dev) and .lambda_handler (prod)