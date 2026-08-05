#!/bin/bash
set -uo pipefail
exec > >(tee -a /tmp/cluster-up.log) 2>&1

REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="wskorea26-cluster"
CLUSTER_YAML_PATH="/home/ec2-user/eks/cluster.yaml"
BASTION_SG="${bastion_sg_id}"
VPC_ENV_SG="${vpc_environment_sg_id}"

STATUS=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $REGION_CODE --query 'cluster.status' --output text 2>/dev/null || echo "NONE")

if [ "$STATUS" = "ACTIVE" ]; then
  echo ">> cluster already ACTIVE, skipping create"
else
  eksctl create cluster -f "$CLUSTER_YAML_PATH"
fi

aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $REGION_CODE
su - ec2-user -c "aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $REGION_CODE"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --region $REGION_CODE --principal-arn arn:aws:iam::$${ACCOUNT_ID}:root 2>/dev/null || true
aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAME --region $REGION_CODE --principal-arn arn:aws:iam::$${ACCOUNT_ID}:root --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster 2>/dev/null || true

echo ">> opening cluster SG 443 for bastion / vpc-environment-sg (grading access)..."
CSG=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $REGION_CODE --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
echo ">> cluster security group: $CSG"

aws ec2 authorize-security-group-ingress --region $REGION_CODE --group-id $CSG --protocol tcp --port 443 --source-group $BASTION_SG
aws ec2 authorize-security-group-ingress --region $REGION_CODE --group-id $CSG --protocol tcp --port 443 --source-group $VPC_ENV_SG
# SG 참조 규칙이 어떤 이유로든 적용되지 않는 경우를 대비한 이중 안전장치 (VPC 전체 대역 허용)
aws ec2 authorize-security-group-ingress --region $REGION_CODE --group-id $CSG --protocol tcp --port 443 --cidr 172.16.0.0/16

echo ">> cluster SG 443 inbound rules:"
aws ec2 describe-security-group-rules --region $REGION_CODE --filters "Name=group-id,Values=$CSG" --query "SecurityGroupRules[?IsEgress==\`false\` && FromPort==\`443\`]" --output table

echo ">> nodes:"
kubectl get nodes
