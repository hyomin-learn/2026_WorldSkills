#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
REGION_CODE="ap-northeast-2"
ECR_NAME="unicorn-concert-app"
IMAGE_TAG="v1.0.0"
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION_CODE.amazonaws.com/$ECR_NAME"

aws ecr get-login-password --region $REGION_CODE | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION_CODE.amazonaws.com"
docker build -t "$ECR_URI:$IMAGE_TAG" "/home/ec2-user/ecr/"
docker tag "$ECR_URI:$IMAGE_TAG" "$ECR_URI:latest"
docker push "$ECR_URI:$IMAGE_TAG"
docker push "$ECR_URI:latest"

sed -i "s|IMAGE|$ECR_URI:$IMAGE_TAG|g" /home/ec2-user/eks/manifest/deployment.yaml