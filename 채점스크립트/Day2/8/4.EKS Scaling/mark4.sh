#!/bin/bash

export PATH="$HOME/.local/bin:$PATH"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    KUBECTL_ARCH="amd64"
    AWSCLI_ARCH="x86_64"
    ;;
  aarch64|arm64)
    KUBECTL_ARCH="arm64"
    AWSCLI_ARCH="aarch64"
    ;;
  *)
    echo "지원하지 않는 CPU 아키텍처입니다: $ARCH"
    exit 2
    ;;
esac

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v grep >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  sudo dnf install -y curl jq grep unzip
fi

if ! command -v kubectl >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  curl -L -o "$HOME/.local/bin/kubectl" "https://dl.k8s.io/release/v1.35.0/bin/linux/${KUBECTL_ARCH}/kubectl"
  chmod +x "$HOME/.local/bin/kubectl"
fi

if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWSCLI_ARCH}.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install --install-dir "$HOME/usr/local/aws-cli" --bin-dir "$HOME/.local/bin" --update
fi

aws --version
curl --version
jq --version
grep --version
unzip -v | head -n 1
kubectl version --client
aws sts get-caller-identity --output table

echo =====4-1=====
aws eks describe-cluster --region us-west-2 --name skills-sqs-cluster --query 'cluster.{Name:name,Status:status,Endpoint:endpoint,Version:version,Role:roleArn,Vpc:resourcesVpcConfig.vpcId,Subnets:resourcesVpcConfig.subnetIds}' --output table
aws eks describe-fargate-profile --region us-west-2 --cluster-name skills-sqs-cluster --fargate-profile-name skills-sqs-fp-keda --query 'fargateProfile.{Name:fargateProfileName,Status:status,Selectors:selectors,Subnets:subnets}' --output table
aws eks describe-fargate-profile --region us-west-2 --cluster-name skills-sqs-cluster --fargate-profile-name skills-sqs-fp-karpenter --query 'fargateProfile.{Name:fargateProfileName,Status:status,Selectors:selectors,Subnets:subnets}' --output table
aws eks update-kubeconfig --region us-west-2 --name skills-sqs-cluster
kubectl get nodes -l eks.amazonaws.com/compute-type=fargate -o wide
echo

echo =====4-2=====
QUEUE_URL=$(aws sqs get-queue-url --region us-west-2 --queue-name skills-sqs-queue --query QueueUrl --output text 2>/dev/null || true)
echo "QUEUE_URL=${QUEUE_URL}"
if [ -n "$QUEUE_URL" ] && [ "$QUEUE_URL" != "None" ]; then
  aws sqs get-queue-attributes --region us-west-2 --queue-url "$QUEUE_URL" --attribute-names QueueArn VisibilityTimeout --output table
else
  echo "skills-sqs-queue Queue URL 식별 실패"
fi
kubectl get serviceaccount keda-operator -n keda -o jsonpath='keda/keda-operator role={.metadata.annotations.eks\.amazonaws\.com/role-arn}{"\n"}'
kubectl get serviceaccount karpenter -n karpenter -o jsonpath='karpenter/karpenter role={.metadata.annotations.eks\.amazonaws\.com/role-arn}{"\n"}'
kubectl get serviceaccount sqs-worker-sa -n skills-sqs -o jsonpath='skills-sqs/sqs-worker-sa role={.metadata.annotations.eks\.amazonaws\.com/role-arn}{"\n"}'
echo

echo =====4-3=====
kubectl get deployment,pod -n keda -o wide
kubectl get deployment,pod -n karpenter -o wide
echo

echo =====4-4=====
kubectl get deployment sqs-worker -n skills-sqs -o jsonpath='name={.metadata.name}{"\n"}serviceAccountName={.spec.template.spec.serviceAccountName}{"\n"}selector={.spec.selector.matchLabels}{"\n"}podLabels={.spec.template.metadata.labels}{"\n"}nodeSelector={.spec.template.spec.nodeSelector}{"\n"}env={.spec.template.spec.containers[0].env}{"\n"}image={.spec.template.spec.containers[0].image}{"\n"}'
kubectl get scaledobject sqs-worker-scaledobject -n skills-sqs -o json | jq '{name:.metadata.name, namespace:.metadata.namespace, scaleTargetRef:.spec.scaleTargetRef, minReplicaCount:.spec.minReplicaCount, maxReplicaCount:.spec.maxReplicaCount, pollingInterval:.spec.pollingInterval, cooldownPeriod:.spec.cooldownPeriod, triggers:.spec.triggers}'
kubectl get triggerauthentication sqs-worker-trigger-auth -n skills-sqs -o json | jq '{name:.metadata.name, namespace:.metadata.namespace, podIdentity:.spec.podIdentity, secretTargetRef:.spec.secretTargetRef, env:.spec.env}'
echo

echo =====4-5=====
kubectl get nodepool skills-sqs-nodepool -o json | jq '{name:.metadata.name, labels:.spec.template.metadata.labels, nodeClassRef:.spec.template.spec.nodeClassRef, requirements:.spec.template.spec.requirements, consolidationPolicy:.spec.disruption.consolidationPolicy}'
kubectl get ec2nodeclass skills-sqs-nodeclass -o json | jq '{name:.metadata.name, role:.spec.role, instanceProfile:.spec.instanceProfile, subnetSelectorTerms:.spec.subnetSelectorTerms, securityGroupSelectorTerms:.spec.securityGroupSelectorTerms, amiFamily:.spec.amiFamily}'
kubectl get nodes -l karpenter.sh/nodepool=skills-sqs-nodepool,skills-nodepool=event-worker -o wide
kubectl get pods -n skills-sqs -l app=sqs-worker -o wide
echo

echo =====4-6=====
if [ -z "$QUEUE_URL" ] || [ "$QUEUE_URL" = "None" ]; then
  echo "skills-sqs-queue Queue URL 식별 실패"
else
  SENT=0
  for I in $(seq 1 12); do
    aws sqs send-message --region us-west-2 --queue-url "$QUEUE_URL" --message-body "judge-$I" >/dev/null 2>&1 && SENT=$((SENT + 1))
  done
  echo "sent=${SENT}"
  for T in 60 120 180; do
    sleep 60
    echo "after_${T}s"
    aws sqs get-queue-attributes --region us-west-2 --queue-url "$QUEUE_URL" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed --output table
    kubectl get deployment sqs-worker -n skills-sqs
    kubectl get pods -n skills-sqs -l app=sqs-worker -o wide
    kubectl get nodes -l karpenter.sh/nodepool=skills-sqs-nodepool,skills-nodepool=event-worker -o wide
    kubectl get nodeclaims -l karpenter.sh/nodepool=skills-sqs-nodepool
  done
fi
echo