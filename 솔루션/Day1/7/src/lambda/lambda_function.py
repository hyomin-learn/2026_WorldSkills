import boto3
import json

REGION_CODE = "ap-northeast-2"
TABLE_NAME = "unicorn-concert-db"

dynamodb = boto3.resource('dynamodb', region_name=REGION_CODE)
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    try:
        params = event.get("queryStringParameters") or {}
        
        booking_id = params.get("booking_id")
        
        email = params.get("email")
        concert_name = params.get("concert_name")

        if not booking_id:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({"msg": "booking_id is required"})
            }

        res = table.get_item(Key={"booking_id": booking_id})

        if "Item" not in res:
            return {
                "statusCode": 404,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({"msg": "Item not found"})
            }

        item = res["Item"]

        if (email and item.get("email") != email) or \
           (concert_name and item.get("concert_name") != concert_name):
            return {
                "statusCode": 404,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({"msg": "Item does not match the optional conditions"})
            }

        response_body = {
            "username": item.get("username"),
            "created_at": item.get("created_at"),
            "email": item.get("email"),
            "booking_id": item.get("booking_id"),
            "client_id": item.get("client_id"),
            "concert_name": item.get("concert_name")
        }

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(response_body)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"msg": str(e)})
        }