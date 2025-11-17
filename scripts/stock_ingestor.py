import json
import boto3
import base64
import os
import uuid
from datetime import datetime

s3 = boto3.client("s3")
ddb = boto3.resource("dynamodb")

RAW_BUCKET = os.environ["RAW_BUCKET"]
TABLE_NAME = os.environ["DDB_TABLE"]

table = ddb.Table(TABLE_NAME)


def lambda_handler(event, context):
    """
    Lambda function triggered by Kinesis.
    Saves raw data to S3 and metadata to DynamoDB.
    """

    responses = []

    for record in event.get("Records", []):
        # Kinesis data is base64 encoded
        payload = base64.b64decode(record["kinesis"]["data"]).decode("utf-8")

        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            data = {"raw": payload}

        # --- Generate file name for S3 ---
        timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%S")
        unique_id = str(uuid.uuid4())
        s3_key = f"ingest/{timestamp}-{unique_id}.json"

        # --- Save raw event to S3 ---
        s3.put_object(
            Bucket=RAW_BUCKET,
            Key=s3_key,
            Body=json.dumps(data),
            ContentType="application/json"
        )

        # --- Save metadata to DynamoDB ---
        table.put_item(
            Item={
                "id": unique_id,
                "timestamp": timestamp,
                "s3_key": s3_key,
                "payload": data
            }
        )

        responses.append({"status": "OK", "id": unique_id, "s3_key": s3_key})

    return {
        "statusCode": 200,
        "message": "Ingest complete",
        "records": responses
    }
