#!/bin/bash
set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
REGION_CODE="ap-northeast-2"

declare -A ECR_REPO_MAP=(
    ["user"]="apdev-user-ecr"
    ["product"]="apdev-product-ecr"
    ["stress"]="apdev-stress-ecr"
)

ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION_CODE.amazonaws.com"

aws ecr get-login-password --region "$REGION_CODE" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"

for IMAGE_TAG in "${!ECR_REPO_MAP[@]}"; do
    REPO_NAME="${ECR_REPO_MAP[$IMAGE_TAG]}"
    ECR_URI="$ECR_REGISTRY/$REPO_NAME"

    echo ">>> Building $IMAGE_TAG -> $ECR_URI:$IMAGE_TAG"

    docker build -t "$ECR_URI:$IMAGE_TAG" "/home/ec2-user/ecr/$IMAGE_TAG"
    docker push "$ECR_URI:$IMAGE_TAG"

    sed -i "s|IMAGE|$ECR_URI:$IMAGE_TAG|g" "/home/ec2-user/eks/manifest/$IMAGE_TAG/deployment.yaml"
done