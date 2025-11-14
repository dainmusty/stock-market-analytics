import os
import json
import time
import boto3
import yfinance as yf
from datetime import datetime

# Initialize Kinesis client
REGION = os.getenv("AWS_REGION", "us-east-1")
kinesis = boto3.client("kinesis", region_name=REGION)

# Read stream name from environment variable (fallback to dev default)
STREAM_NAME = os.getenv("STREAM_NAME", "dev-stock-stream")

# List of stock symbols to monitor
STOCKS = ["AAPL", "GOOGL", "AMZN", "MSFT", "TSLA"]


def get_stock_data(symbol):
    """Fetch latest stock data from Yahoo Finance"""
    ticker = yf.Ticker(symbol)
    data = ticker.history(period="1d", interval="1m")

    if not data.empty:
        latest = data.tail(1).iloc[0]
        return {
            "symbol": symbol,
            "timestamp": datetime.utcnow().isoformat(),
            "open": round(latest["Open"], 2),
            "high": round(latest["High"], 2),
            "low": round(latest["Low"], 2),
            "close": round(latest["Close"], 2),
            "volume": int(latest["Volume"]),
        }
    return None


def send_to_kinesis(record):
    """Push JSON record to Kinesis"""
    response = kinesis.put_record(
        StreamName=STREAM_NAME,
        Data=json.dumps(record),
        PartitionKey=record["symbol"],
    )
    return response


def run_producer():
    """Continuously fetch and push stock data"""
    while True:
        print(f"Fetching and pushing stock data at {datetime.utcnow()} ...")
        for stock in STOCKS:
            stock_data = get_stock_data(stock)
            if stock_data:
                send_to_kinesis(stock_data)
                print(f"✅ Sent {stock_data['symbol']} data to Kinesis")
        print("Sleeping for 60 seconds...\n")
        time.sleep(60)


# Lambda handler wrapper
def lambda_handler(event, context):
    """AWS Lambda entry point"""
    print("Lambda execution started")
    for stock in STOCKS:
        stock_data = get_stock_data(stock)
        if stock_data:
            send_to_kinesis(stock_data)
            print(f"✅ Sent {stock_data['symbol']} data to Kinesis")
    print("Lambda execution completed")
    return {"status": "success"}


# Local test mode
if __name__ == "__main__":
    run_producer()
