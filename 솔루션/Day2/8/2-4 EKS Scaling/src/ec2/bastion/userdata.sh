#!/bin/bash
REGION_CODE="us-west-2"

dnf update -y
dnf upgrade -y
dnf install --allowerasing -y jq curl wget unzip vim dos2unix
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config
systemctl restart sshd
echo 'Skill53##' | passwd --stdin ec2-user
echo 'Skill53##' | passwd --stdin root

dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
chmod 666 /var/run/docker.sock

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.2/2026-02-27/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
rm -rf get_helm.sh

mkdir k9s && cd k9s/
curl -LO https://github.com/derailed/k9s/releases/download/v0.50.18/k9s_Linux_amd64.tar.gz
tar -xf k9s_Linux_amd64.tar.gz
chmod +x k9s
sudo mv k9s /usr/local/bin
cd ..
rm -rf k9s

S3_BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'skills-sqs-image')].Name" --output text --region $REGION_CODE)
aws s3 cp s3://$S3_BUCKET_NAME/ /home/ec2-user/ --recursive --region $REGION_CODE
aws s3 rb s3://$S3_BUCKET_NAME --force --region $REGION_CODE

chown -R ec2-user:ec2-user /home/ec2-user/
chmod +x /home/ec2-user/scripts/*
dos2unix /home/ec2-user/scripts/*
/home/ec2-user/scripts/cluster-tag.sh
/home/ec2-user/scripts/docker-image.sh
/home/ec2-user/scripts/kube-setup.sh