# import boto3
# import json
# import time
# from datetime import datetime

# # --- Kinesis setup ---
# STREAM_NAME = "stock-stream-dev"  # match Terraform name
# REGION_NAME = "us-east-1"

# # Initialize boto3 client
# kinesis_client = boto3.client("kinesis", region_name=REGION_NAME)

# # Simulate reading from a radio log file (replace with your real log file path)
# LOG_FILE = "/var/log/radio_stream.log"

# def read_radio_logs(log_file):
#     """Generator to yield log lines one by one."""
#     with open(log_file, "r") as file:
#         for line in file:
#             yield line.strip()

# def format_log_for_kinesis(raw_line):
#     """Convert raw log line into JSON for Kinesis."""
#     # Example log format: listener_id, program_name, timestamp
#     parts = raw_line.split(",")
#     return {
#         "listener_id": parts[0],
#         "program_name": parts[1],
#         "timestamp": parts[2] if len(parts) > 2 else datetime.utcnow().isoformat()
#     }

# def push_to_kinesis(data):
#     """Push single record to Kinesis."""
#     response = kinesis_client.put_record(
#         StreamName=STREAM_NAME,
#         Data=json.dumps(data),
#         PartitionKey=data["listener_id"]  # ensures balanced shard distribution
#     )
#     return response

# def main():
#     print(f"Starting log producer for stream: {STREAM_NAME}")
#     for line in read_radio_logs(LOG_FILE):
#         record = format_log_for_kinesis(line)
#         push_to_kinesis(record)
#         print(f"Pushed: {record}")
#         time.sleep(1)  # adjust to control ingestion rate

# if __name__ == "__main__":
#     main()
