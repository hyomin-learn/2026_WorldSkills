#!/bin/bash
REGION_CODE="ap-northeast-2"
S3_BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'apdev-logs')].Name" --output text --region $REGION_CODE)
PREFIX="athena-results/"

aws s3 rm "s3://$S3_BUCKET_NAME/$PREFIX" --recursive --region $REGION_CODE