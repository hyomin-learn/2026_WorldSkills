#!/bin/bash
ALB_NAME="wsc2026-app-alb"
CLOUDFRONT_NAME="wsc2026-cdn"
CLOUDFRONT_FUNCTION_NAME="wsc2026-cdn-function"

ALB_DNS=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query "LoadBalancers[].DNSName" --output text)
CLOUDFRONT_ID=$(aws resourcegroupstaggingapi get-resources --tag-filters Key=Name,Values=$CLOUDFRONT_NAME --resource-type-filters 'cloudfront' --region us-east-1 --query "ResourceTagMappingList[0].ResourceARN" --output text | sed 's:.*/::')
CLOUDFRONT_FUNCTION_ARN=$(aws cloudfront describe-function --name $CLOUDFRONT_FUNCTION_NAME --region us-east-1 --query "FunctionSummary.FunctionMetadata.FunctionARN" --output text)
CLOUDFRONT_ETAG=$(aws cloudfront get-distribution --id $CLOUDFRONT_ID --query "ETag" --output text)

aws cloudfront get-distribution-config --id $CLOUDFRONT_ID > /home/ec2-user/dist-config.json

jq --arg ALB "$ALB_DNS" --arg CLOUDFRONT_FUNCTION_ARN "$CLOUDFRONT_FUNCTION_ARN" '
.DistributionConfig as $d
| $d

| .Origins.Items = (
    ($d.Origins.Items // []) + [
      {
        "Id": "alb_origin",
        "DomainName": $ALB,
        "OriginPath": "",
        "CustomHeaders": { "Quantity": 0 },
        "ConnectionAttempts": 3,
        "ConnectionTimeout": 10,
        "OriginShield": { "Enabled": false },
        "OriginAccessControlId": "",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 3,
            "Items": ["TLSv1", "TLSv1.1", "TLSv1.2"]
          },
          "OriginReadTimeout": 30,
          "OriginKeepaliveTimeout": 5
        }
      }
    ]
  )
| .Origins.Quantity = (.Origins.Items | length)

| .CacheBehaviors.Items = (
    ($d.CacheBehaviors.Items // []) + [
      {
        "PathPattern": "/booking",
        "TargetOriginId": "alb_origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
          "Quantity": 7,
          "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
          "CachedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
          }
        },
        "Compress": true,
        "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
        "OriginRequestPolicyId": "216adef6-5c7f-47e4-b989-5492eafa07d3",
        "FieldLevelEncryptionId": "",
        "TrustedSigners": { "Enabled": false, "Quantity": 0 },
        "TrustedKeyGroups": { "Enabled": false, "Quantity": 0 },
        "LambdaFunctionAssociations": { "Quantity": 0 },
        
        "FunctionAssociations": {
          "Quantity": 1,
          "Items": [
            {
              "FunctionARN": $CLOUDFRONT_FUNCTION_ARN,
              "EventType": "viewer-request"
            }
          ]
        },
        "SmoothStreaming": false,
        "GrpcConfig": { "Enabled": false }
      }
    ]
  )
| .CacheBehaviors.Quantity = (.CacheBehaviors.Items | length)
' /home/ec2-user/dist-config.json > /home/ec2-user/dist-config-final.json

aws cloudfront update-distribution --id $CLOUDFRONT_ID --if-match $CLOUDFRONT_ETAG --distribution-config file:///home/ec2-user/dist-config-final.json > /dev/null

rm -rf /home/ec2-user/*.json