#!/bin/bash
set -x
exec > /var/log/bastion-bootstrap.log 2>&1

# --------------------------- Base packages ---------------------------
# (전체 dnf update/upgrade 는 공간만 많이 먹어 제거. 필요한 패키지만 설치)
dnf install --allowerasing -y jq unzip vim git tar gzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# --------------------------- Timezone ---------------------------
timedatectl set-timezone Asia/Seoul

# --------------------------- Docker ---------------------------
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
chmod 666 /var/run/docker.sock

# --------------------------- SSH password login (편의) ---------------------------
sed -i 's|#\?PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config
systemctl restart sshd
echo 'Skill53##' | passwd --stdin ec2-user || true
echo 'Skill53##' | passwd --stdin root || true

# --------------------------- eksctl ---------------------------
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# --------------------------- kubectl (1.35) ---------------------------
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.2/2026-02-27/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin

# --------------------------- helm ---------------------------
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm -f get_helm.sh

# --------------------------- k9s ---------------------------
mkdir k9s && cd k9s/
curl -LO https://github.com/derailed/k9s/releases/download/v0.50.18/k9s_Linux_amd64.tar.gz
tar -xf k9s_Linux_amd64.tar.gz
chmod +x k9s
mv k9s /usr/local/bin
cd ..
rm -rf k9s

# --------------------------- App source ---------------------------
mkdir -p /home/ec2-user/o11y/app

cat > /home/ec2-user/o11y/app/app.py <<'APP_PY'
${app_py}
APP_PY

cat > /home/ec2-user/o11y/app/Dockerfile <<'DOCKERFILE'
${dockerfile}
DOCKERFILE

# --------------------------- Build & push to ECR ---------------------------
REGISTRY=$(echo "${ecr_url}" | cut -d/ -f1)
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin "$REGISTRY"

cd /home/ec2-user/o11y/app
docker build -t ${ecr_url}:latest .
docker push ${ecr_url}:latest

# --------------------------- eksctl cluster config ---------------------------
cat > /home/ec2-user/o11y/cluster.yaml <<'CLUSTER_YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${cluster_name}
  region: ${region}
  version: "${cluster_version}"

# 기존 Terraform VPC/Subnet 재사용
vpc:
  id: ${vpc_id}
  subnets:
    public:
      ${az_a}: { id: ${pub_subnet_a} }
      ${az_c}: { id: ${pub_subnet_c} }
    private:
      ${az_a}: { id: ${priv_subnet_a} }
      ${az_c}: { id: ${priv_subnet_c} }

iam:
  withOIDC: true

# 클러스터는 Bastion 롤이 생성하므로 기본적으로 그 principal 만 admin 입니다.
# 채점자/실행자(terraform 실행 주체)도 kubectl 이 되도록 access entry 를 추가합니다.
accessConfig:
  authenticationMode: API_AND_CONFIG_MAP
  accessEntries:
    - principalARN: ${admin_arn}
      accessPolicies:
        - policyARN: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
          accessScope:
            type: cluster

managedNodeGroups:
  - name: ng-1
    instanceType: t3.medium
    minSize: 2
    desiredCapacity: 2
    maxSize: 2
    privateNetworking: true
    availabilityZones: ["${az_a}", "${az_c}"]
    volumeSize: 30
    # 모든 노드 TimeZone = KST
    preBootstrapCommands:
      - "timedatectl set-timezone Asia/Seoul"

addons:
  - name: aws-ebs-csi-driver   # Loki PVC용
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
CLUSTER_YAML

# --------------------------- Helper: create cluster ---------------------------
cat > /home/ec2-user/o11y/00-create-cluster.sh <<'CREATE_SH'
#!/bin/bash
set -e
eksctl create cluster -f /home/ec2-user/o11y/cluster.yaml
aws eks update-kubeconfig --name ${cluster_name} --region ${region}
echo "cluster ready"
CREATE_SH
chmod +x /home/ec2-user/o11y/00-create-cluster.sh

# --------------------------- Pull kubernetes/ from S3 ---------------------------
# Terraform 이 ${artifacts_bucket} 에 올려둔 배포 매니페스트를 받아옵니다.
aws s3 cp "s3://${artifacts_bucket}/kubernetes/" /home/ec2-user/o11y/kubernetes/ \
  --recursive --region ${region}
chmod +x /home/ec2-user/o11y/kubernetes/*.sh 2>/dev/null || true

echo "export ECR_URL=${ecr_url}" >> /home/ec2-user/.bashrc
echo "export AWS_REGION=${region}" >> /home/ec2-user/.bashrc
echo "export COMPETITOR=${competitor_number}" >> /home/ec2-user/.bashrc
echo "export ALB_SG_ID=${alb_sg_id}" >> /home/ec2-user/.bashrc
echo "export APP_TG_ARN=${app_tg_arn}" >> /home/ec2-user/.bashrc
echo "export GRAFANA_TG_ARN=${grafana_tg_arn}" >> /home/ec2-user/.bashrc

chown -R ec2-user:ec2-user /home/ec2-user/o11y

# --------------------------- Auto deploy script ---------------------------
# 실행은 Terraform 의 null_resource(remote-exec)가 SSH 로 트리거합니다.
# (여기서 백그라운드로 돌리지 않음 → apply 가 완료까지 기다리고 실패를 잡아냄)
cat > /home/ec2-user/o11y/01-autodeploy.sh <<'AUTO_SH'
#!/bin/bash
# stdout 은 화면(=terraform 로그)으로 흘리면서 파일에도 남깁니다.
exec > >(tee -a /var/log/o11y-autodeploy.log) 2>&1

export AWS_REGION=${region}
export AWS_DEFAULT_REGION=${region}
export ECR_URL=${ecr_url}
export COMPETITOR=${competitor_number}
export ALB_SG_ID=${alb_sg_id}
export APP_TG_ARN=${app_tg_arn}
export GRAFANA_TG_ARN=${grafana_tg_arn}
export PATH=$PATH:/usr/local/bin

echo "=== AUTODEPLOY START $(date) ==="

# 1) EKS 클러스터 (이미 있으면 건너뜀 - 재실행 안전)
if aws eks describe-cluster --name ${cluster_name} --region ${region} >/dev/null 2>&1; then
  echo ">>> cluster already exists, skipping create"
else
  echo ">>> creating EKS cluster (15~20 min)..."
  eksctl create cluster -f /home/ec2-user/o11y/cluster.yaml || {
    echo "!!! cluster create FAILED"; exit 1; }
fi

aws eks update-kubeconfig --name ${cluster_name} --region ${region}

# 클러스터가 이미 있던 경우 등 accessEntries 가 반영 안 됐을 수 있으므로 한 번 더 보장.
# (이미 존재하면 에러 무시)
echo ">>> granting cluster-admin to ${admin_arn}"
aws eks create-access-entry --cluster-name ${cluster_name} --region ${region} \
  --principal-arn '${admin_arn}' --type STANDARD 2>/dev/null || true
aws eks associate-access-policy --cluster-name ${cluster_name} --region ${region} \
  --principal-arn '${admin_arn}' \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster 2>/dev/null || true

kubectl get nodes || { echo "!!! cluster not reachable"; exit 1; }

# 2) 워크로드 (LBC IRSA -> Loki -> OTel -> App -> Grafana)
echo ">>> deploying workloads..."
cd /home/ec2-user/o11y/kubernetes
bash deploy.sh "$COMPETITOR" || { echo "!!! deploy.sh FAILED"; exit 1; }

touch /home/ec2-user/o11y/.autodeploy-complete
echo "=== AUTODEPLOY DONE $(date) ==="
AUTO_SH

chmod +x /home/ec2-user/o11y/01-autodeploy.sh
chown -R ec2-user:ec2-user /home/ec2-user/o11y
touch /var/log/o11y-autodeploy.log
chown ec2-user:ec2-user /var/log/o11y-autodeploy.log

echo "BOOTSTRAP DONE (autodeploy is triggered by terraform remote-exec)"
