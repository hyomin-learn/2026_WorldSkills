#!/bin/bash
REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="skm-eks-cluster"
EKS_NODE_GROUP_NAME="skm-cluster-addon-ng"
EKS_CLUSTER_NAME="skm-eks-cluster"
PUBLIC_A_SN_NAME="skm-pub-sn-a"
PUBLIC_C_SN_NAME="skm-pub-sn-c"
PRIVATE_A_SN_NAME="skm-priv-sn-a"
PRIVATE_C_SN_NAME="skm-priv-sn-c"

PUBLIC_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PUBLIC_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
EKS_NODE_GROUP_SECURITY_GROUP_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$EKS_NODE_GROUP_NAME" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].SecurityGroups[].GroupId" --output text --region $REGION_CODE)

aws ec2 create-tags --resources $EKS_NODE_GROUP_SECURITY_GROUP_ID --tags Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME

SN_IDS=("$PUBLIC_A_SN_ID" "$PUBLIC_C_SN_ID" "$PRIVATE_A_SN_ID" "$PRIVATE_C_SN_ID")

for name in "${SN_IDS[@]}"
do
    aws ec2 create-tags --resources $name --tags Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME
done