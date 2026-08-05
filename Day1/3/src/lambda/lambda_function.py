from boto3.dynamodb.conditions import Key
from datetime import timedelta, timezone
from collections import OrderedDict
from datetime import datetime
from base64 import b64decode
import boto3
import json
import os
import time

REGION_CODE = "ap-northeast-2"
ENCRYPTED = os.environ['TABLE_NAME']
TABLE_NAME = boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED))['Plaintext'].decode('utf-8')

dynamodb = boto3.resource('dynamodb', region_name=REGION_CODE)
table = dynamodb.Table(TABLE_NAME)

logs_client = boto3.client('logs', region_name=REGION_CODE)
LOG_GROUP_NAME = "/wsc2026/pod/log"
LOG_STREAM_NAME = "/wsc2026/app/log"

def put_custom_log(level, path, status, duration, method):
    log_detail = {
        "level": level,
        "path": path,
        "status": str(status),
        "duration": f"{duration:.6f}ms",
        "method": method
    }
    log_message = json.dumps(log_detail, separators=(",", ":"))
    
    try:
        logs_client.put_log_events(
            logGroupName=LOG_GROUP_NAME,
            logStreamName=LOG_STREAM_NAME,
            logEvents=[
                {
                    'timestamp': int(time.time() * 1000),
                    'message': log_message
                }
            ]
        )
    except Exception as e:
        print(f"Failed to send log to CloudWatch: {e}")

def lambda_handler(event, context):
    start_time = time.time()
    
    path = event["requestContext"]["http"]["path"]
    method = event["requestContext"]["http"]["method"]

    try:
        params = event.get("queryStringParameters") or {}
        booking_id = params.get("booking_id")

        if not booking_id:
            status_code = 400
            duration = (time.time() - start_time) * 1000
            put_custom_log("WARN", path, status_code, duration, method)
            
            return {
                "statusCode": status_code,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({"msg": "booking_id required"})
            }

        res = table.query(IndexName="booking_id-index", KeyConditionExpression=Key('booking_id').eq(booking_id))

        if not res.get("Items"):
            status_code = 404
            duration = (time.time() - start_time) * 1000
            put_custom_log("WARN", path, status_code, duration, method)
            
            return {
                "statusCode": status_code,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({"msg": "Item not found"})
            }

        item = res["Items"][0]

        created_at_utc = item.get("created_at")
        try:
            utc_dt = datetime.strptime(created_at_utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            kst_tz = timezone(timedelta(hours=9))
            created_at_kst = utc_dt.astimezone(kst_tz).strftime("%Y-%m-%d %H:%M:%S KST")
        except Exception:
            created_at_kst = created_at_utc

        response_body = OrderedDict([
            ("client_id", item.get("client_id")),
            ("username", item.get("username")),
            ("email", item.get("email")),
            ("concert_name", item.get("concert_name")),
            ("created_at", created_at_kst)
        ])

        status_code = 200
        duration = (time.time() - start_time) * 1000
        put_custom_log("INFO", path, status_code, duration, method)

        return {
            "statusCode": status_code,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(response_body)
        }

    except Exception as e:
        status_code = 500
        duration = (time.time() - start_time) * 1000
        put_custom_log("ERROR", path, status_code, duration, method)
        
        return {
            "statusCode": status_code,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"msg": str(e)})
        }