#!/bin/bash
REGION_CODE="us-west-2"
EKS_CLUSTER_NAME="skills-sqs-cluster"
EKS_CLUSTER_NAME="skills-sqs-cluster"
PUBLIC_A_SN_NAME="skills-sqs-public-a"
PUBLIC_C_SN_NAME="skills-sqs-public-c"
PRIVATE_A_SN_NAME="skills-sqs-private-a"
PRIVATE_C_SN_NAME="skills-sqs-private-c"
SECURITY_GROUP_NAME="skills-sqs-eks-nodegroup-sg"

PUBLIC_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PUBLIC_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
EKS_NODE_GROUP_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='$SECURITY_GROUP_NAME'].GroupId" --output text --region $REGION_CODE)

aws ec2 create-tags --resources $EKS_NODE_GROUP_SECURITY_GROUP_ID --tags Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME

SN_IDS=("$PUBLIC_A_SN_ID" "$PUBLIC_C_SN_ID" "$PRIVATE_A_SN_ID" "$PRIVATE_C_SN_ID")

for name in "${SN_IDS[@]}"
do
    aws ec2 create-tags --resources $name --tags Key=karpenter.sh/discovery,Value=$EKS_CLUSTER_NAME
done