import base64
import json
import logging
import os
from decimal import Decimal

import boto3
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

DDB_TABLE = os.environ["DDB_TABLE"]
ALERT_TOPIC = os.environ["ALERT_TOPIC"]
BOOTSTRAP_SERVER = os.environ["BOOTSTRAP_SERVER"]
AWS_REGION = os.environ.get("AWS_REGION", "ap-northeast-1")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(DDB_TABLE)

_producer = None


class MSKTokenProvider:
    def token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


def _json_default(o):
    if isinstance(o, Decimal):
        return float(o)
    raise TypeError(f"Object of type {type(o).__name__} is not JSON serializable")


def get_producer():
    global _producer
    if _producer is None:
        _producer = KafkaProducer(
            bootstrap_servers=BOOTSTRAP_SERVER.split(","),
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=MSKTokenProvider(),
            value_serializer=lambda v: json.dumps(v, default=_json_default).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
        )
    return _producer


def evaluate(temperature, humidity):
    if temperature > 80:
        return "ALERT", f"Temperature exceeded threshold: {temperature}°C"
    if temperature < 10:
        return "ALERT", f"Temperature below threshold: {temperature}°C"
    if humidity > 90:
        return "ALERT", f"Humidity exceeded threshold: {humidity}%"
    if humidity < 20:
        return "ALERT", f"Humidity below threshold: {humidity}%"
    return "NORMAL", None


def handler(event, context):
    records = event.get("records", {})
    count = sum(len(v) for v in records.values())
    logger.info("Processing batch: %d messages", count)

    for _, messages in records.items():
        for msg in messages:
            payload = base64.b64decode(msg["value"])
            data = json.loads(payload, parse_float=Decimal)

            sensor_id = data["sensorId"]
            temperature = float(data["temperature"])
            humidity = float(data["humidity"])

            status, reason = evaluate(temperature, humidity)

            if status == "NORMAL":
                table.put_item(
                    Item={
                        "sensorId": sensor_id,
                        "timestamp": data["timestamp"],
                        "temperature": data["temperature"],
                        "humidity": data["humidity"],
                        "location": data["location"],
                        "status": "NORMAL",
                    }
                )
                logger.info(
                    "%s: NORMAL - temp=%s°C, humidity=%s%%",
                    sensor_id, temperature, humidity,
                )
            else:
                alert_payload = dict(data)
                alert_payload["status"] = "ALERT"
                alert_payload["alert_reason"] = reason

                get_producer().send(ALERT_TOPIC, key=sensor_id, value=alert_payload)
                get_producer().flush()

                logger.info(
                    "%s: ALERT - temp=%s°C (%s)",
                    sensor_id, temperature, reason,
                )

    return {"batchItemFailures": []}
