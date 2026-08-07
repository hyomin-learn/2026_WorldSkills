#!/bin/bash
# CloudShell에서 진행
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
EKS_CLUSTER_NAME="unicorn-eks-cluster"
REGION_CODE="ap-northeast-2"
ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/unicorn-audit-role

aws iam create-user --user-name unicorn-user 2> /dev/null

aws iam attach-user-policy --user-name unicorn-user --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2> /dev/null
aws iam put-user-policy --user-name unicorn-user --policy-name allow-assume-unicorn-audit-role --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"sts:AssumeRole","Resource":"'"$ROLE_ARN"'"}]}'

AK=$(aws iam list-access-keys --user-name unicorn-user --query "AccessKeyMetadata[].AccessKeyId" --output text 2> /dev/null)

aws iam delete-access-key --user-name unicorn-user --access-key-id $AK 2> /dev/null

read -r AK SK < <(aws iam create-access-key --user-name unicorn-user --query "AccessKey.[AccessKeyId,SecretAccessKey]" --output text)

echo "export AWS_ACCESS_KEY_ID=$AK" >> ~/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=$SK" >> ~/.bashrc
echo "rm -rf ~/.kube/" >> ~/.bashrc

echo "aws eks delete-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:user/unicorn-user --region $REGION_CODE > /dev/null" >> ~/.bashrc
echo "aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:user/unicorn-user --region $REGION_CODE > /dev/null" >> ~/.bashrc
echo "aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:user/unicorn-user --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region $REGION_CODE > /dev/null" >> ~/.bashrc

source ~/.bashrc