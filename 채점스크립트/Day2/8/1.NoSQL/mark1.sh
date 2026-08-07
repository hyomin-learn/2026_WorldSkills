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

export NOSQL_CLIENT_EC2_PUBLIC_IP=$(aws ec2 describe-instances --region ap-northeast-2 --filters Name=tag:Name,Values=skills-nosql-client-ec2 Name=instance-state-name,Values=running --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo =====1-1=====
aws docdb describe-db-clusters --region ap-northeast-2 --db-cluster-identifier skills-nosql-docdb-cluster --query 'DBClusters[0].{Cluster:DBClusterIdentifier,Status:Status,Engine:Engine,Version:EngineVersion,Encrypted:StorageEncrypted,KmsKeyId:KmsKeyId,BackupRetention:BackupRetentionPeriod,Endpoint:Endpoint,Port:Port}' --output table
aws docdb describe-db-instances --region ap-northeast-2 --db-instance-identifier skills-nosql-docdb-instance-1 --query 'DBInstances[0].{Instance:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Engine:Engine,Cluster:DBClusterIdentifier,AZ:AvailabilityZone}' --output table
aws kms describe-key --region ap-northeast-2 --key-id alias/skills-nosql-docdb --query 'KeyMetadata.{Arn:Arn,Enabled:Enabled,KeyManager:KeyManager,KeyUsage:KeyUsage}' --output table
echo

echo =====1-2=====
aws secretsmanager describe-secret --region ap-northeast-2 --secret-id skills-nosql-docdb-secret --query '{Name:Name,ARN:ARN,KmsKeyId:KmsKeyId}' --output table
aws secretsmanager get-secret-value --region ap-northeast-2 --secret-id skills-nosql-docdb-secret --query SecretString --output text | jq -r '{username, host, password_set:(.password != null and .password != "")}'
aws ec2 describe-instances --region ap-northeast-2 --filters Name=tag:Name,Values=skills-nosql-client-ec2 Name=instance-state-name,Values=running --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress}' --output table
echo

echo =====1-3=====
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/health"
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/admin/summary"
echo

echo =====1-4=====
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/admin/indexes"
echo

echo =====1-5=====
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/orders/O-1001"
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/customers/C001/orders"
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/orders/pending?from=2026-06-01T00:00:00Z&to=2026-06-08T00:00:00Z"
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${NOSQL_CLIENT_EC2_PUBLIC_IP}:8080/v1/products/low-stock?warehouseId=W-A"
echo