#!/bin/bash
ALB_NAME="unicorn-alb"
CLOUDFRONT_NAME="unicorn-svc-cf"
TARGET_GROUP_NAME="unicorn-tg"
CLOUDFRONT_VPC_ORIGIN_NAME="unicorn-alb-origin"

ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query "LoadBalancers[].LoadBalancerArn" --output text)
ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[?Port==\`80\`].ListenerArn" --output text)
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names $TARGET_GROUP_NAME --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 create-rule --listener-arn $ALB_LISTENER_ARN --priority 3 --conditions Field=path-pattern,Values="/v1/book" Field=http-request-method,HttpRequestMethodConfig="{Values=[GET]}" --actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN > /dev/null

cat > /home/ec2-user/cloudfront-vpc-origin.json <<EOF
{
  "Name": "$CLOUDFRONT_VPC_ORIGIN_NAME",
  "Arn": "$ALB_ARN",
  "HTTPPort": 80,
  "HTTPSPort": 443,
  "OriginProtocolPolicy": "http-only",
  "OriginSslProtocols": {
    "Quantity": 1,
    "Items": ["TLSv1.2"]
  }
}
EOF

aws cloudfront create-vpc-origin --vpc-origin-endpoint-config file:///home/ec2-user/cloudfront-vpc-origin.json > /dev/null

while true; do
  CLOUDFRONT_VPC_ORIGIN_STATUS=$(aws cloudfront list-vpc-origins --query "VpcOriginList.Items[?Name=='$CLOUDFRONT_VPC_ORIGIN_NAME'].Status | [0]" --output text)

  if [ "$CLOUDFRONT_VPC_ORIGIN_STATUS" == "Deployed" ]; then
    echo $CLOUDFRONT_VPC_ORIGIN_STATUS
    break
  fi
  echo $CLOUDFRONT_VPC_ORIGIN_STATUS
  sleep 10
done

ALB_DNS=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query "LoadBalancers[].DNSName" --output text)
CLOUDFRONT_ID=$(aws resourcegroupstaggingapi get-resources --tag-filters Key=Name,Values=$CLOUDFRONT_NAME --resource-type-filters 'cloudfront' --region us-east-1 --query "ResourceTagMappingList[0].ResourceARN" --output text | sed 's:.*/::')
CLOUDFRONT_VPC_ORIGIN_ID=$(aws cloudfront list-vpc-origins --query "VpcOriginList.Items[?Name=='$CLOUDFRONT_VPC_ORIGIN_NAME'].Id" --output text)
CLOUDFRONT_ETAG=$(aws cloudfront get-distribution --id $CLOUDFRONT_ID --query "ETag" --output text)
aws cloudfront get-distribution-config --id $CLOUDFRONT_ID > /home/ec2-user/dist-config.json

jq --arg ALB_DNS "$ALB_DNS" --arg VPC_ORIGIN_NAME "$CLOUDFRONT_VPC_ORIGIN_NAME" --arg VPC_ORIGIN_ID "$CLOUDFRONT_VPC_ORIGIN_ID" '
.DistributionConfig as $d
| $d
| .Origins.Items = (
    ($d.Origins.Items // []) + [
      {
        "Id": "app-origin",
        "DomainName": $ALB_DNS,
        "OriginPath": "",
        "VpcOriginConfig": {
          "VpcOriginId": $VPC_ORIGIN_ID,
          "OriginReadTimeout": 30,
          "OriginKeepaliveTimeout": 5
        },
        "CustomHeaders": {
          "Quantity": 0
        },
        "ConnectionAttempts": 3,
        "ConnectionTimeout": 10,
        "OriginShield": {
          "Enabled": false
        },
        "OriginAccessControlId": ""
      }
    ]
  )
| .Origins.Quantity = (.Origins.Items | length)
| .CacheBehaviors.Items = (
    ($d.CacheBehaviors.Items // []) + [
      {
        "PathPattern": "/v1/*",
        "TargetOriginId": "app-origin",
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
        "TrustedSigners": {
          "Enabled": false,
          "Quantity": 0
        },
        "TrustedKeyGroups": {
          "Enabled": false,
          "Quantity": 0
        },
        "LambdaFunctionAssociations": { "Quantity": 0 },
        "FunctionAssociations": { "Quantity": 0 },
        "SmoothStreaming": false,
        "GrpcConfig": { "Enabled": false }
      },
      {
        "PathPattern": "/health",
        "TargetOriginId": "app-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
          "Quantity": 2,
          "Items": ["GET", "HEAD"],
          "CachedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
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
        "LambdaFunctionAssociations": { "Quantity": 0 },
        "FunctionAssociations": { "Quantity": 0 },
        "SmoothStreaming": false,
        "GrpcConfig": { "Enabled": false }
      }
    ]
  )
| .CacheBehaviors.Quantity = (.CacheBehaviors.Items | length)
' /home/ec2-user/dist-config.json > /home/ec2-user/dist-config-final.json

aws cloudfront update-distribution --id $CLOUDFRONT_ID --if-match $CLOUDFRONT_ETAG --distribution-config file:///home/ec2-user/dist-config-final.json > /dev/null

rm -rf /home/ec2-user/*.json