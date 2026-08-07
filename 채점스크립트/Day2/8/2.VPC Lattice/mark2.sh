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

export LATTICE_CLIENT_EC2_PUBLIC_IP=$(aws ec2 describe-instances --region ap-northeast-1 --filters Name=tag:Name,Values=skills-lattice-client-ec2 Name=instance-state-name,Values=running --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
export SERVICE_NETWORK_ID=$(aws vpc-lattice list-service-networks --region ap-northeast-1 --query "items[?name=='skills-lattice-sn'].id | [0]" --output text)
export TARGET_GROUP_ID=$(aws vpc-lattice list-target-groups --region ap-northeast-1 --query "items[?name=='skills-lattice-order-tg'].id | [0]" --output text)
export SERVICE_ID=$(aws vpc-lattice list-services --region ap-northeast-1 --query "items[?name=='skills-lattice-order-service'].id | [0]" --output text)
export SERVICE_EC2_SECURITY_GROUP_ID=$(aws ec2 describe-instances --region ap-northeast-1 --filters Name=tag:Name,Values=skills-lattice-service-ec2 Name=instance-state-name,Values=running --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text)

echo =====2-1=====
aws ec2 describe-vpcs --region ap-northeast-1 --filters Name=tag:Name,Values=skills-lattice-client-vpc,skills-lattice-service-vpc --query 'Vpcs[].{Name:Tags[?Key==`Name`].Value|[0],VpcId:VpcId,Cidr:CidrBlock,State:State}' --output table
echo

echo =====2-2=====
aws ec2 describe-instances --region ap-northeast-1 --filters Name=tag:Name,Values=skills-lattice-client-ec2,skills-lattice-service-ec2 Name=instance-state-name,Values=running --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],Id:InstanceId,Type:InstanceType,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,State:State.Name}' --output table
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${LATTICE_CLIENT_EC2_PUBLIC_IP}/health"
echo

echo =====2-3=====
aws vpc-lattice list-service-networks --region ap-northeast-1 --query 'items[?name==`skills-lattice-sn`].{Name:name,Id:id,AssociatedVPCs:numberOfAssociatedVPCs,AssociatedServices:numberOfAssociatedServices}' --output table
aws vpc-lattice list-services --region ap-northeast-1 --query 'items[?name==`skills-lattice-order-service`].{Name:name,Id:id,Dns:dnsEntry.domainName,Status:status}' --output table
aws vpc-lattice list-service-network-vpc-associations --region ap-northeast-1 --service-network-identifier "$SERVICE_NETWORK_ID" --query 'items[].{AssociationId:id,VpcId:vpcId,Status:status}' --output table
aws vpc-lattice get-service-network-vpc-association --region ap-northeast-1 --service-network-vpc-association-identifier "$VPC_ASSOCIATION_ID" --query '{AssociationId:id,VpcId:vpcId,Status:status,SecurityGroupIds:securityGroupIds}' --output table
aws vpc-lattice list-service-network-service-associations --region ap-northeast-1 --service-network-identifier "$SERVICE_NETWORK_ID" --query 'items[].{ServiceId:serviceId,Status:status,Dns:dnsEntry.domainName}' --output table
echo

echo =====2-4=====
aws vpc-lattice list-target-groups --region ap-northeast-1 --query 'items[?name==`skills-lattice-order-tg`].{Name:name,Id:id,Type:type,Port:port,Protocol:protocol,Vpc:vpcIdentifier,Status:status}' --output table
aws vpc-lattice list-targets --region ap-northeast-1 --target-group-identifier "$TARGET_GROUP_ID" --query 'items[].{Target:id,Port:port,Status:status}' --output table
aws vpc-lattice list-listeners --region ap-northeast-1 --service-identifier "$SERVICE_ID" --query 'items[?name==`skills-lattice-http-listener`].{Name:name,Id:id,Port:port,Protocol:protocol}' --output table
aws ec2 describe-security-groups --region ap-northeast-1 --group-ids $SERVICE_EC2_SECURITY_GROUP_ID --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId,Inbound:IpPermissions}' --output json
echo

echo =====2-5=====
curl -s -m 10 -w "\nhttp_code=%{http_code}\n" "http://${LATTICE_CLIENT_EC2_PUBLIC_IP}/v1/client/orders?id=1001"
echo