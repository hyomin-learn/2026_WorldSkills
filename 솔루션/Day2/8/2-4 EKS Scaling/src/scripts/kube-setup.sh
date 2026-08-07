#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION_CODE="us-west-2"
EKS_CLUSTER_NAME="skills-sqs-cluster"
SQS_NAME="skills-sqs-queue"
EKS_NODE_GROUP_NAME="skills-sqs-node"
SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name $SQS_NAME --query "QueueUrl" --output text)

CLUSTER_YAML_PATH=$(sudo find / -name "cluster.yaml" 2>/dev/null)

eksctl create cluster -f $CLUSTER_YAML_PATH
aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME
su - ec2-user -c 'REGION_CODE="us-west-2"; EKS_CLUSTER_NAME="skills-sqs-cluster"; aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME'

aws eks create-access-entry --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:user/wsc-user --region $REGION_CODE > /dev/null
aws eks associate-access-policy --cluster-name $EKS_CLUSTER_NAME --principal-arn arn:aws:iam::$ACCOUNT_ID:user/wsc-user --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region $REGION_CODE > /dev/null

kubectl create ns skills-sqs

/home/ec2-user/scripts/karpenter-tag.sh

KARPENTER_ROLE_NAME=$(aws iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n' | grep -i karpenter)
sed -i "s|KARPENTER_ROLE_NAME|$KARPENTER_ROLE_NAME|g" /home/ec2-user/eks/manifest/karpenter.yaml
sed -i "s|SQS_QUEUE_URLS|$SQS_QUEUE_URL|g" /home/ec2-user/eks/manifest/deployment.yaml
sed -i "s|SQS_QUEUE_URL|$SQS_QUEUE_URL|g" /home/ec2-user/eks/manifest/scaledobject.yaml

kubectl apply -f /home/ec2-user/eks/manifest/karpenter.yaml

cat << EOF > /home/ec2-user/eks/manifest/sqs-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GetQueueAttributes",
            "Effect": "Allow",
            "Action": [
                "sqs:GetQueueAttributes",
                "sqs:ReceiveMessage",
                "sqs:GetQueueUrl",
                "sqs:ListQueues",
                "sqs:deletemessage"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy --policy-name SQSPolicy --policy-document file:///home/ec2-user/eks/manifest/sqs-policy.json 2> /dev/null | true

rm -rf /home/ec2-user/eks/manifest/sqs-policy.json

eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --region=$REGION_CODE \
  --name=keda-operator \
  --namespace=keda \
  --role-name=keda-operator-role \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/SQSPolicy \
  --approve

eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --region=$REGION_CODE \
  --name=sqs-worker-sa \
  --namespace=skills-sqs \
  --role-name=sqs-worker-role \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/SQSPolicy \
  --approve

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  -n keda \
  --set serviceAccount.operator.create=false \
  --set serviceAccount.operator.name=keda-operator

sleep 30

kubectl apply -f /home/ec2-user/eks/manifest/karpenter.yaml
kubectl apply -f /home/ec2-user/eks/manifest/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/scaledobject.yaml
kubectl apply -f /home/ec2-user/eks/manifest/triggerauthentication.yaml