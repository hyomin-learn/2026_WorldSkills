{
  "Comment": "Student score processing workflow",
  "StartAt": "CheckS3File",
  "States": {
    "CheckS3File": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:headObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key.$": "$.key"
      },
      "ResultPath": "$.headObjectResult",
      "Next": "ProcessStudentData",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "ProcessStudentData": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${lambda_function_arn}",
        "Payload.$": "$"
      },
      "ResultSelector": {
        "statusCode.$": "$.Payload.statusCode",
        "processed.$": "$.Payload.processed",
        "errors.$": "$.Payload.errors"
      },
      "ResultPath": "$.result",
      "Retry": [
        {
          "ErrorEquals": ["States.ALL"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Next": "CheckResult"
    },
    "CheckResult": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.result.statusCode",
          "NumericEquals": 200,
          "Next": "MoveToProcessed"
        }
      ],
      "Default": "MoveToError"
    },
    "MoveToProcessed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:copyObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "CopySource.$": "States.Format('${bucket_name}/{}', $.key)",
        "Key.$": "States.Format('processed/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"
      },
      "ResultPath": "$.copyResult",
      "Next": "DeleteProcessedSource",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "DeleteProcessedSource": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key.$": "$.key"
      },
      "ResultPath": "$.deleteInputResult",
      "Next": "DeleteProcessedMarker",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "DeleteProcessedMarker": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key": "processed/"
      },
      "ResultPath": "$.deleteProcessedMarkerResult",
      "Next": "DeleteErrorMarkerAfterProcessed",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "DeleteErrorMarkerAfterProcessed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key": "error/"
      },
      "End": true,
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "MoveToError": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:copyObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "CopySource.$": "States.Format('${bucket_name}/{}', $.key)",
        "Key.$": "States.Format('error/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"
      },
      "ResultPath": "$.copyResult",
      "Next": "DeleteErrorSource",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "WorkflowFail"
        }
      ]
    },
    "DeleteErrorSource": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key.$": "$.key"
      },
      "ResultPath": "$.deleteInputResult",
      "Next": "DeleteErrorMarker"
    },
    "DeleteErrorMarker": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key": "error/"
      },
      "Next": "DeleteProcessedMarkerAfterError"
    },
    "DeleteProcessedMarkerAfterError": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:s3:deleteObject",
      "Parameters": {
        "Bucket": "${bucket_name}",
        "Key": "processed/"
      },
      "Next": "WorkflowFail"
    },
    "WorkflowFail": {
      "Type": "Fail"
    }
  }
}
