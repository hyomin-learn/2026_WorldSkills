#!/bin/bash
set -euo pipefail

REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="apdev-eks-cluster"

get_subnet_id() {
  aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=$1" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region "$REGION_CODE"
}

PUBLIC_A_SN_ID=$(get_subnet_id "apdev-public-subnet-a")
PUBLIC_C_SN_ID=$(get_subnet_id "apdev-public-subnet-c")
PRIVATE_A_SN_ID=$(get_subnet_id "apdev-private-subnet-a")
PRIVATE_C_SN_ID=$(get_subnet_id "apdev-private-subnet-c")

CLUSTER_SG_ID=$(aws eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text \
  --region "$REGION_CODE")

if [[ -z "$CLUSTER_SG_ID" || "$CLUSTER_SG_ID" == "None" ]]; then
  echo "ERROR: EKS cluster security group not found."
  exit 1
fi

aws ec2 create-tags \
  --resources "$CLUSTER_SG_ID" \
  --tags "Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME" \
  --region "$REGION_CODE"

for subnet_id in "$PUBLIC_A_SN_ID" "$PUBLIC_C_SN_ID" "$PRIVATE_A_SN_ID" "$PRIVATE_C_SN_ID"; do
  if [[ -n "$subnet_id" && "$subnet_id" != "None" ]]; then
    aws ec2 create-tags \
      --resources "$subnet_id" \
      --tags "Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME" \
      --region "$REGION_CODE"
  fi
done

echo "Karpenter discovery tags configured."
