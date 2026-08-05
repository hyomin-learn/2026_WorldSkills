import json
import os
from datetime import timezone, timedelta

import boto3
from boto3.dynamodb.conditions import Key

TABLE_NAME = os.environ["TABLE_NAME"]
GSI_NAME = os.environ.get("GSI_NAME", "concert_name-created_at-index")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

KST = timezone(timedelta(hours=9))

FIELDS = ["username", "created_at", "email", "booking_id", "client_id", "concert_name"]


def _response(status_code, body_obj):
    return {
        "statusCode": status_code,
        "statusDescription": f"{status_code} {'OK' if status_code == 200 else 'Bad Request'}",
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body_obj, ensure_ascii=False),
    }


def handler(event, context):
    # ALB 대상 그룹 이벤트 포맷
    params = event.get("queryStringParameters") or {}
    concert_name = params.get("concert_name")

    if not concert_name:
        return _response(400, {"message": "concert_name is required"})

    resp = table.query(
        IndexName=GSI_NAME,
        KeyConditionExpression=Key("concert_name").eq(concert_name),
        ScanIndexForward=False,  # DB 레벨 최신순 정렬
    )
    items = resp.get("Items", [])

    result = [{k: it.get(k) for k in FIELDS} for it in items]

    return _response(200, result)
