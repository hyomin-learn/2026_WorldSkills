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

echo =====3-1=====
aws ec2 describe-vpcs --region ap-southeast-1 --filters Name=tag:Name,Values=skills-ceh-vpc --query 'Vpcs[].{Name:Tags[?Key==`Name`].Value|[0],VpcId:VpcId,Cidr:CidrBlock}' --output table
aws ec2 describe-instances --region ap-southeast-1 --filters Name=tag:Name,Values=skills-ceh-ec2 Name=instance-state-name,Values=running --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],Id:InstanceId,Type:InstanceType,State:State.Name,SecurityGroups:SecurityGroups[].GroupId}' --output table
aws ec2 describe-security-groups --region ap-southeast-1 --filters Name=tag:Name,Values=skills-ceh-protected-sg --query 'SecurityGroups[].{Name:Tags[?Key==`Name`].Value|[0],GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}' --output table
echo

echo =====3-2=====
aws ec2 describe-security-groups --region ap-southeast-1 --filters Name=tag:Name,Values=skills-ceh-protected-sg --query 'SecurityGroups[].{GroupId:GroupId,Inbound:IpPermissions,Outbound:IpPermissionsEgress}' --output json
echo

echo =====3-3=====
aws sns list-topics --region ap-southeast-1 --query 'Topics[?contains(TopicArn, `:skills-ceh-alert-topic`)].TopicArn' --output table
aws lambda get-function-configuration --region ap-southeast-1 --function-name skills-ceh-remediate-fn --query '{FunctionName:FunctionName,State:State,LastUpdateStatus:LastUpdateStatus,Runtime:Runtime,Handler:Handler,Timeout:Timeout,Role:Role,Environment:Environment.Variables}' --output table
echo

echo =====3-4=====
aws cloudtrail get-trail-status --region ap-southeast-1 --name skills-ceh-cloudtrail --query '{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError}' --output table
aws events describe-rule --region ap-southeast-1 --name skills-ceh-sg-change-rule --event-bus-name default --query '{Name:Name,State:State,EventPattern:EventPattern}' --output json
aws events list-targets-by-rule --region ap-southeast-1 --rule skills-ceh-sg-change-rule --event-bus-name default --query 'Targets[].{Id:Id,Arn:Arn}' --output table
aws lambda get-policy --region ap-southeast-1 --function-name skills-ceh-remediate-fn --query 'Policy' --output text
echo

echo =====3-5=====
export PROTECTED_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region ap-southeast-1 --filters Name=tag:Name,Values=skills-ceh-protected-sg --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 authorize-security-group-ingress --region ap-southeast-1 --group-id "$PROTECTED_SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
jq -n --arg sg "$PROTECTED_SECURITY_GROUP_ID" '{detail:{eventName:"AuthorizeSecurityGroupIngress",requestParameters:{groupId:$sg}}}' > /tmp/skills-ceh-remediate-event.json
aws lambda invoke --region ap-southeast-1 --function-name skills-ceh-remediate-fn --cli-binary-format raw-in-base64-out --payload file:///tmp/skills-ceh-remediate-event.json /tmp/skills-ceh-remediate-output.json
aws ec2 describe-security-groups --region ap-southeast-1 --group-ids "$PROTECTED_SECURITY_GROUP_ID" --query 'SecurityGroups[0].IpPermissions' --output json
aws logs describe-log-groups --region ap-southeast-1 --log-group-name-prefix /aws/lambda/skills-ceh-remediate-fn --query 'logGroups[].logGroupName' --output table
echo