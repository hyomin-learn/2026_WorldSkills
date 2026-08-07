import json
import os

import boto3

sfn_client = boto3.client("stepfunctions")


def handler(event, context):
    state_machine_arn = os.environ.get("STATE_MACHINE_ARN")

    for record in event.get("Records", []):
        key = record["s3"]["object"]["key"]

        sfn_client.start_execution(
            stateMachineArn=state_machine_arn,
            input=json.dumps({"key": key}),
        )

    return {"statusCode": 200}
