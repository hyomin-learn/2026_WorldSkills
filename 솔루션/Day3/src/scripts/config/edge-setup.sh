#!/bin/bash

ALB_NAME="apdev-app-lb"
CLOUDFRONT_NAME="apdev-cdn"

while true; do
  ALB_STATUS=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query "LoadBalancers[].State.Code" --output text)

  if [ "$ALB_STATUS" == "active" ]; then
    echo $ALB_STATUS
    break
  fi

  echo $ALB_STATUS
  sleep 10
done

ALB_DNS=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query "LoadBalancers[].DNSName" --output text)

CLOUDFRONT_ID=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Name,Values=$CLOUDFRONT_NAME \
  --resource-type-filters 'cloudfront' \
  --region us-east-1 \
  --query "ResourceTagMappingList[0].ResourceARN" \
  --output text | sed 's:.*/::')

CLOUDFRONT_ETAG=$(aws cloudfront get-distribution \
  --id $CLOUDFRONT_ID \
  --query "ETag" \
  --output text)

aws cloudfront get-distribution-config \
  --id $CLOUDFRONT_ID \
  > /home/ec2-user/dist-config.json

jq --arg ALB_DNS "$ALB_DNS" '
.DistributionConfig as $d
| $d

| .Origins.Items = (
    (
      ($d.Origins.Items // [])
      | map(select(.Id != "alb-origin"))
    ) + [
      {
        "Id": "alb-origin",
        "DomainName": $ALB_DNS,
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
            "Items": ["TLSv1","TLSv1.1","TLSv1.2"]
          },
          "OriginReadTimeout": 30,
          "OriginKeepaliveTimeout": 5
        }
      }
    ]
  )
| .Origins.Quantity = (.Origins.Items | length)

| .DefaultCacheBehavior.TargetOriginId = "alb-origin"
| .DefaultCacheBehavior.OriginRequestPolicyId = "216adef6-5c7f-47e4-b989-5492eafa07d3"

| .CacheBehaviors.Items = (
    (
      ($d.CacheBehaviors.Items // [])
      | map(select(.PathPattern != "/v1/*"))
    ) + [
      {
        "PathPattern": "/v1/*",
        "TargetOriginId": "alb-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
          "Quantity": 7,
          "Items": [
            "GET",
            "HEAD",
            "OPTIONS",
            "PUT",
            "POST",
            "PATCH",
            "DELETE"
          ],
          "CachedMethods": {
            "Quantity": 2,
            "Items": [
              "GET",
              "HEAD"
            ]
          }
        },
        "Compress": true,
        "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
        "OriginRequestPolicyId": "216adef6-5c7f-47e4-b989-5492eafa07d3",
        "FieldLevelEncryptionId": "",
        "TrustedSigners": {
          "Enabled": false,
          "Quantity": 0
        },
        "TrustedKeyGroups": {
          "Enabled": false,
          "Quantity": 0
        },
        "LambdaFunctionAssociations": {
          "Quantity": 0
        },
        "FunctionAssociations": {
          "Quantity": 0
        },
        "SmoothStreaming": false,
        "GrpcConfig": {
          "Enabled": false
        }
      }
    ]
  )
| .CacheBehaviors.Quantity = (.CacheBehaviors.Items | length)
' /home/ec2-user/dist-config.json > /home/ec2-user/dist-config-final.json

aws cloudfront update-distribution \
  --id $CLOUDFRONT_ID \
  --if-match $CLOUDFRONT_ETAG \
  --distribution-config file:///home/ec2-user/dist-config-final.json

rm -f /home/ec2-user/dist-config*.json