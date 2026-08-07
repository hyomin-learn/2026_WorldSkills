#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="wsc2026-eks-cluster"
APP_EKS_NODE_GROUP_NAME="wsc2026-workload-node"
ALB_SECURITY_GROUP_NAME="wsc2026-app-alb-sg"
FLUENT_BIT_ROLE_NAME="wsc2026-fluent-bit-role"
GRAFANA_ROLE_NAME="wsc2026-grafana-role"
DYNAMODB_ROLE_NAME="wsc2026-book-pod-role"

CLUSTER_YAML_PATH=$(sudo find / -name "cluster.yaml" 2>/dev/null)
FLUENT_BIT_ROLE_ARN=$(aws iam get-role --role-name $FLUENT_BIT_ROLE_NAME --query "Role.Arn" --output text --region $REGION_CODE)
GRAFANA_ROLE_ARN=$(aws iam get-role --role-name $GRAFANA_ROLE_NAME --query "Role.Arn" --output text --region $REGION_CODE)
DYNAMODB_ROLE_ARN=$(aws iam get-role --role-name $DYNAMODB_ROLE_NAME --query "Role.Arn" --output text --region $REGION_CODE)

eksctl create cluster -f $CLUSTER_YAML_PATH
aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME
su - ec2-user -c 'REGION_CODE="ap-northeast-2"; EKS_CLUSTER_NAME="wsc2026-eks-cluster"; aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME'

aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:root --region $REGION_CODE > /dev/null
aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:root --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region $REGION_CODE > /dev/null

kubectl get configmaps coredns -n kube-system -o yaml > /home/ec2-user/eks/manifest/coredns.yaml
sed -i "s|cluster.local|wsc2026.skills.local|g" /home/ec2-user/eks/manifest/coredns.yaml
kubectl apply -f /home/ec2-user/eks/manifest/coredns.yaml --force
rm -rf /home/ec2-user/eks/manifest/coredns.yaml
kubectl rollout restart deploy/coredns -n kube-system

kubectl create ns wsc2026
kubectl create ns observability

eksctl create addon --cluster $EKS_CLUSTER_NAME --name=eks-pod-identity-agent --region $REGION_CODE --force

eksctl create podidentityassociation \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace "observability" \
  --service-account-name "wsc2026-fluent-bit-sa" \
  --role-arn $FLUENT_BIT_ROLE_ARN \
  --create-service-account

kubectl apply -f /home/ec2-user/eks/manifest/logging/configmap.yaml
kubectl apply -f /home/ec2-user/eks/manifest/logging/daemonset.yaml

eksctl create podidentityassociation \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace "wsc2026" \
  --service-account-name "wsc2026-book-sa" \
  --role-arn $DYNAMODB_ROLE_ARN \
  --create-service-account

KMS_KEY_ALIASE_NAME="alias/wsc2026-db-kms"
KMS_KEY_ARN=$(aws kms describe-key --key-id $KMS_KEY_ALIASE_NAME --query "KeyMetadata.Arn" --output text --region $REGION_CODE)
aws iam put-role-policy --role-name $DYNAMODB_ROLE_NAME --policy-name AllowKMSDecrypt --policy-document "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Action\": \"kms:Decrypt\",\"Resource\": \"${KMS_KEY_ARN}\"}]}"

kubectl apply -f /home/ec2-user/eks/manifest/pdb.yaml
kubectl apply -f /home/ec2-user/eks/manifest/configmap.yaml
kubectl apply -f /home/ec2-user/eks/manifest/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/service.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$EKS_CLUSTER_NAME \
  -f /home/ec2-user/eks/manifest/ingress/values.yaml

ALB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='$ALB_SECURITY_GROUP_NAME'].GroupId" --output text --region $REGION_CODE)
EKS_CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text --region $REGION_CODE)
aws ec2 authorize-security-group-ingress --group-id $EKS_CLUSTER_SECURITY_GROUP_ID --protocol tcp --port 8080 --source-group $ALB_SECURITY_GROUP_ID > /dev/null

sed -i "s|SECURITY_GROUP_ID|$ALB_SECURITY_GROUP_ID|g" /home/ec2-user/eks/manifest/ingress/ingress.yaml

sleep 20

kubectl apply -f /home/ec2-user/eks/manifest/ingress/ingress.yaml

eksctl utils associate-iam-oidc-provider --region $REGION_CODE --cluster $EKS_CLUSTER_NAME --approve

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace kube-system \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2 \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --service-account-role-arn arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
  --force

sleep 10

kubectl apply -f /home/ec2-user/eks/manifest/prometheus/sc.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade -i prometheus prometheus-community/prometheus \
  -n observability \
  -f /home/ec2-user/eks/manifest/prometheus/values.yaml

sleep 30

kubectl apply -f /home/ec2-user/eks/manifest/grafana/configmap.yaml

eksctl create podidentityassociation \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace "observability" \
  --service-account-name "wsc2026-grafana-sa" \
  --role-arn $GRAFANA_ROLE_ARN \
  --create-service-account

helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm upgrade -i grafana grafana-community/grafana \
  -n observability \
  -f /home/ec2-user/eks/manifest/grafana/values.yaml