import base64
import json
import logging
import os

import boto3

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
S3_BUCKET = os.environ["S3_BUCKET"]

sns = boto3.client("sns")
s3 = boto3.client("s3")


def handler(event, context):
    records = event.get("records", {})
    count = sum(len(v) for v in records.values())
    logger.info("Processing batch: %d messages", count)

    for _, messages in records.items():
        for msg in messages:
            payload = base64.b64decode(msg["value"])
            data = json.loads(payload)

            sensor_id = data["sensorId"]
            timestamp = data["timestamp"]
            alert_reason = data.get("alert_reason", "")

            message = (
                f"Sensor ID: {sensor_id}\n"
                f"Time: {timestamp}\n"
                f"Reason: {alert_reason}\n"
                f"Temperature: {data.get('temperature')}\n"
                f"Humidity: {data.get('humidity')}\n"
                f"Location: {data.get('location')}"
            )

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"[ALERT] {sensor_id}",
                Message=message,
            )

            date_str = timestamp[:10]
            key = f"alert/{sensor_id}/{date_str}/{timestamp}.json"

            s3.put_object(
                Bucket=S3_BUCKET,
                Key=key,
                Body=json.dumps(data).encode("utf-8"),
                ContentType="application/json",
            )

            logger.info("%s: ALERT logged to s3://%s/%s", sensor_id, S3_BUCKET, key)

    return {"batchItemFailures": []}
