#!/bin/bash
set -euo pipefail
REGION_CODE="ap-northeast-2"
CLUSTER_NAME="apdev-eks-cluster"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

dnf update -y
dnf upgrade -y
dnf install -y cronie
systemctl enable --now crond
dnf install --allowerasing -y jq curl wget unzip vim dos2unix
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo dnf install -y "https://s3.${REGION_CODE}.amazonaws.com/amazon-ssm-${REGION_CODE}/latest/linux_amd64/amazon-ssm-agent.rpm"
dnf install -y mariadb105

cat <<'EOF' > /etc/ssh/sshd_config.d/00-enable-password-auth.conf
PasswordAuthentication yes
PermitRootLogin yes
EOF
systemctl restart sshd
echo 'Skill53##' | passwd --stdin ec2-user
echo 'Skill53##' | passwd --stdin root

dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
chmod 666 /var/run/docker.sock

curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.2/2026-02-27/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm -rf get_helm.sh

mkdir k9s && cd k9s/
curl -LO https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_Linux_amd64.tar.gz
tar -xf k9s_Linux_amd64.tar.gz
chmod +x k9s
sudo mv k9s /usr/local/bin
cd ..
rm -rf k9s

S3_BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'image')].Name" --output text --region $REGION_CODE)
aws s3 cp s3://$S3_BUCKET_NAME/ /home/ec2-user/ --recursive --region $REGION_CODE

if [ -f "/home/ec2-user/rds/dump.sql" ]; then
    cp /home/ec2-user/rds/dump.sql /home/ec2-user/rds/load_user.dump
fi

aws s3 rb s3://$S3_BUCKET_NAME --force --region $REGION_CODE

chown -R ec2-user:ec2-user /home/ec2-user/
chmod +x /home/ec2-user/scripts/config/*
chmod +x /home/ec2-user/scripts/load/*
dos2unix /home/ec2-user/scripts/config/*
dos2unix /home/ec2-user/scripts/load/*

/home/ec2-user/scripts/config/cluster-tag.sh
/home/ec2-user/scripts/config/docker-images.sh
/home/ec2-user/scripts/config/rds-setup.sh
/home/ec2-user/scripts/config/kube-setup.sh

aws eks update-kubeconfig \
  --region $REGION_CODE \
  --name $CLUSTER_NAME

/home/ec2-user/scripts/config/karpenter-tag.sh

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "apdev-app-ng" \
  --scaling-config minSize=2,maxSize=3,desiredSize=2 \
  --region "$REGION_CODE"

echo "EKS 노드 3대 확장 요청 완료"

for i in $(seq 1 60); do
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)

    echo "Ready 노드 수: ${NODE_COUNT}/3"

    if [ "$NODE_COUNT" -ge 3 ]; then
        echo "EKS 노드 3대 준비 완료"
        break
    fi

    sleep 10
done

if [ "$NODE_COUNT" -lt 3 ]; then
    echo "ERROR: 3번째 EKS 노드가 10분 내에 Ready 상태가 되지 않았습니다."
    exit 1
fi

ALB_NAME="apdev-app-lb"
ALB_READY=false

for i in $(seq 1 60); do
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --names "$ALB_NAME" \
      --query "LoadBalancers[].DNSName" \
      --output text \
      --region "$REGION_CODE" 2>/dev/null)

    if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
        echo "ALB 생성: $ALB_DNS"
        ALB_READY=true
        break
    fi

    echo "ALB 생성 대기 중($i/60)"
    sleep 10
done

if [ "$ALB_READY" = true ]; then
    /home/ec2-user/scripts/config/edge-setup.sh
else
    echo "ALB가 생성되지 않음"
fi