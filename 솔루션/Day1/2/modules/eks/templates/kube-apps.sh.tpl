#!/bin/bash
set -uo pipefail
exec > >(tee -a /tmp/kube-apps.log) 2>&1

REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="wskorea26-cluster"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_IMAGE="${ecr_repo_url}:stable"
MANIFEST="/home/ec2-user/eks/manifest"

aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $REGION_CODE

kubectl create ns wskorea26  --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -

# --------------------------- 6. ECR : book 이미지 빌드 & 푸시 (tag: stable) ---------------------------
aws ecr get-login-password --region $REGION_CODE | docker login --username AWS --password-stdin "$${ECR_IMAGE%%/*}"
docker build -t "$ECR_IMAGE" /home/ec2-user/eks/book
docker push "$ECR_IMAGE"

echo ">> waiting for ECR image scan to complete..."
for i in $(seq 1 30); do
  ST=$(aws ecr describe-image-scan-findings --repository-name "${ecr_repo_name}" --image-id imageTag=stable --region $REGION_CODE --query 'imageScanStatus.status' --output text 2>/dev/null || echo "IN_PROGRESS")
  if [ "$ST" = "COMPLETE" ]; then echo ">> scan complete"; break; fi
  sleep 10
done

# --------------------------- IRSA(OIDC) : book-sa -> DynamoDB 쓰기 권한 ---------------------------
# eks-pod-identity-agent 는 모든 노드(addon+app)에 DaemonSet 으로 배포되어 5-4 채점
# (kube-system 파드는 전부 addon 노드에 있어야 함) 을 깨뜨리므로 IRSA(OIDC) 를 사용한다.
OIDC_ISSUER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $REGION_CODE --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$${OIDC_ISSUER#https://}

BOOK_ROLE="wskorea26-book-dynamodb-role"
cat > /tmp/book-trust.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::$${ACCOUNT_ID}:oidc-provider/$${OIDC_ID}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$${OIDC_ID}:sub": "system:serviceaccount:wskorea26:book-sa",
          "$${OIDC_ID}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
JSON
aws iam create-role --role-name $BOOK_ROLE --assume-role-policy-document file:///tmp/book-trust.json > /dev/null 2>&1 || \
  aws iam update-assume-role-policy --role-name $BOOK_ROLE --policy-document file:///tmp/book-trust.json
aws iam attach-role-policy --role-name $BOOK_ROLE --policy-arn "${book_write_policy_arn}"
kubectl -n wskorea26 create serviceaccount book-sa --dry-run=client -o yaml \
  | kubectl annotate --local -f - eks.amazonaws.com/role-arn="arn:aws:iam::$${ACCOUNT_ID}:role/$${BOOK_ROLE}" -o yaml \
  | kubectl apply -f -

# --------------------------- 8. book 애플리케이션 배포 ---------------------------
kubectl apply -f $MANIFEST/book/deployment.yaml
# 이미지 태그는 항상 'stable'로 동일하므로, 재푸시된 새 이미지를 기존 파드가 확실히 다시 받도록 강제 재시작
kubectl -n wskorea26 rollout restart deployment/book
kubectl -n wskorea26 rollout status deployment/book --timeout=180s || true

# --------------------------- 10. ALB 대상그룹에 노드그룹 ASG 연결 ---------------------------
APP_ASG=$(aws eks describe-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name wskorea26-app-ng --region $REGION_CODE --query "nodegroup.resources.autoScalingGroups[0].name" --output text)
aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name "$APP_ASG" --target-group-arns "${book_target_group_arn}" --region $REGION_CODE

ADDON_ASG=$(aws eks describe-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name wskorea26-addon-ng --region $REGION_CODE --query "nodegroup.resources.autoScalingGroups[0].name" --output text)
aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name "$ADDON_ASG" --target-group-arns "${grafana_target_group_arn}" --region $REGION_CODE

# --------------------------- 12. Monitoring : Fluent Bit (로그 -> CloudWatch Logs) ---------------------------
FB_ROLE="wskorea26-fluentbit-role"
cat > /tmp/fb-trust.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::$${ACCOUNT_ID}:oidc-provider/$${OIDC_ID}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$${OIDC_ID}:sub": "system:serviceaccount:monitoring:aws-for-fluent-bit",
          "$${OIDC_ID}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
JSON
aws iam create-role --role-name $FB_ROLE --assume-role-policy-document file:///tmp/fb-trust.json > /dev/null 2>&1 || \
  aws iam update-assume-role-policy --role-name $FB_ROLE --policy-document file:///tmp/fb-trust.json
aws iam attach-role-policy --role-name $FB_ROLE --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
kubectl -n monitoring create serviceaccount aws-for-fluent-bit --dry-run=client -o yaml \
  | kubectl annotate --local -f - eks.amazonaws.com/role-arn="arn:aws:iam::$${ACCOUNT_ID}:role/$${FB_ROLE}" -o yaml \
  | kubectl apply -f -

helm repo add eks https://aws.github.io/eks-charts > /dev/null
helm repo update > /dev/null

helm upgrade -i aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n monitoring \
  -f $MANIFEST/fluent-bit/values.yaml || true

# --------------------------- 12. Monitoring : Prometheus (클러스터 메트릭 수집) ---------------------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null
helm upgrade -i prometheus prometheus-community/prometheus \
  -n monitoring \
  -f $MANIFEST/prometheus/values.yaml || true

# --------------------------- 12. Monitoring : Grafana (대시보드) ---------------------------
kubectl apply -f $MANIFEST/grafana/configmap.yaml

helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo update > /dev/null
helm upgrade -i grafana grafana/grafana \
  -n monitoring \
  -f $MANIFEST/grafana/values.yaml
kubectl -n monitoring rollout status deployment/grafana --timeout=180s || echo ">> WARNING: grafana rollout 확인 실패, kubectl get pods -n monitoring / kubectl describe pod 로 원인 확인 필요"

echo ">> done."
