#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="skm-eks-cluster"
SQS_NAME="skm-order-queue"
EKS_NODE_GROUP_NAME="skm-cluster-addon-ng"
SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name $SQS_NAME --query "QueueUrl" --output text)

CLUSTER_YAML_PATH="/home/ec2-user/eks/cluster.yaml"


aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME
su - ec2-user -c 'REGION_CODE="ap-northeast-2"; EKS_CLUSTER_NAME="skm-eks-cluster"; aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME'

/home/ec2-user/scripts/karpenter-tag.sh

kubectl create ns skillsmkt

KARPENTER_ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'KarpenterNodeRole')].RoleName" --output text)

sed -i "s|KARPENTER_ROLE_NAME|$KARPENTER_ROLE_NAME|g" /home/ec2-user/eks/manifest/karpenter.yaml
sed -i "s|SQS_QUEUE_URL|$SQS_QUEUE_URL|g" /home/ec2-user/eks/manifest/scaledobject.yaml

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

aws iam create-policy --policy-name SQSPolicy --policy-document file:///home/ec2-user/eks/manifest/sqs-policy.json > /dev/null

rm -rf /home/ec2-user/eks/manifest/sqs-policy.json

eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --region=$REGION_CODE \
  --name=keda-operator \
  --namespace=skm-scaling \
  --role-name=keda-operator-role \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/SQSPolicy \
  --approve

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda \
  -n skm-scaling \
  --set serviceAccount.operator.create=false \
  --set serviceAccount.operator.name=keda-operator

sleep 30

kubectl apply -f /home/ec2-user/eks/manifest/karpenter.yaml
kubectl apply -f /home/ec2-user/eks/manifest/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/scaledobject.yaml