#!/bin/bash
REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="unicorn-eks-cluster"
PUBLIC_A_SN_NAME="unicorn-subnet-pub-a"
PUBLIC_B_SN_NAME="unicorn-subnet-pub-b"
PUBLIC_C_SN_NAME="unicorn-subnet-pub-c"
PRIVATE_A_SN_NAME="unicorn-subnet-priv-a"
PRIVATE_B_SN_NAME="unicorn-subnet-priv-b"
PRIVATE_C_SN_NAME="unicorn-subnet-priv-c"
KMS_KEY_ALIASE_NAME="alias/unicorn-kms-platform"
SECURITY_GROUP_NAME="unicorn-eks-control-plane-sg"

PUBLIC_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PUBLIC_B_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_B_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PUBLIC_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_A_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_A_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_B_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_B_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
PRIVATE_C_SN_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_C_SN_NAME" --query "Subnets[].SubnetId[]" --output text --region $REGION_CODE)
KMS_KEY_ARN=$(aws kms describe-key --key-id $KMS_KEY_ALIASE_NAME --query "KeyMetadata.Arn" --output text --region $REGION_CODE)
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=$SECURITY_GROUP_NAME" --query "SecurityGroups[].GroupId" --output text)
CLUSTER_YAML_PATH=$(sudo find / -name "cluster.yaml" 2> /dev/null)

sed -i "s|KMS_KEY_ARN|$KMS_KEY_ARN|g" $CLUSTER_YAML_PATH
sed -i "s|KMS_KEY_ID|$KMS_KEY_ARN|g" $CLUSTER_YAML_PATH
sed -i "s|SECURITY_GROUP_ID|$SECURITY_GROUP_ID|g" $CLUSTER_YAML_PATH
sed -i "s|PRIVATE_A|$PRIVATE_A_SN_ID|g" $CLUSTER_YAML_PATH
sed -i "s|PRIVATE_B|$PRIVATE_B_SN_ID|g" $CLUSTER_YAML_PATH
sed -i "s|PRIVATE_C|$PRIVATE_C_SN_ID|g" $CLUSTER_YAML_PATH

PUBLIC_SN_IDS=("$PUBLIC_A_SN_ID" "$PUBLIC_B_SN_ID" "$PUBLIC_C_SN_ID")
PRIVATE_SN_IDS=("$PRIVATE_A_SN_ID" "$PRIVATE_B_SN_ID" "$PRIVATE_C_SN_ID")

for name in "${PUBLIC_SN_IDS[@]}"
do
    aws ec2 create-tags --resources $name --tags Key=kubernetes.io/cluster/$EKS_CLUSTER_NAME,Value=shared
    aws ec2 create-tags --resources $name --tags Key=kubernetes.io/role/elb,Value=1
done

for name in "${PRIVATE_SN_IDS[@]}"
do
    aws ec2 create-tags --resources $name --tags Key=kubernetes.io/cluster/$EKS_CLUSTER_NAME,Value=shared
    aws ec2 create-tags --resources $name --tags Key=kubernetes.io/role/internal-elb,Value=1
done