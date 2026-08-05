#!/bin/bash
# Bastion 에서 실행. 클러스터(00-create-cluster.sh)가 먼저 떠 있어야 합니다.
set -e

: "${ECR_URL:?ECR_URL env not set (source ~/.bashrc)}"
: "${ALB_SG_ID:?ALB_SG_ID env not set (source ~/.bashrc)}"
: "${APP_TG_ARN:?APP_TG_ARN env not set (source ~/.bashrc)}"
: "${GRAFANA_TG_ARN:?GRAFANA_TG_ARN env not set (source ~/.bashrc)}"

# 선수등록번호: 인자로 주면 그 값, 없으면 terraform 이 심어둔 $COMPETITOR 사용
COMPETITOR="${1:-$COMPETITOR}"
: "${COMPETITOR:?선수등록번호 없음. './deploy.sh 53' 처럼 인자로 주거나 source ~/.bashrc}"

cd "$(dirname "$0")"

# ---- Helm repos ----
helm repo add eks https://aws.github.io/eks-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# ---- AWS Load Balancer Controller (TargetGroupBinding CRD + 컨트롤러) ----
CLUSTER_NAME=$(kubectl config current-context | cut -d/ -f2)
REGION="${AWS_REGION:-ap-northeast-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# OIDC provider (이미 있으면 무시)
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" --region "$REGION" --approve || true

# LBC IAM 정책 (이미 있으면 무시)
if ! aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy" >/dev/null 2>&1; then
  curl -sLo /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/iam-policy.json
fi

# IRSA (ServiceAccount + IAM Role). 이미 있으면 무시
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" --region "$REGION" \
  --namespace kube-system --name aws-load-balancer-controller \
  --attach-policy-arn "arn:aws:iam::$ACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts --approve || true

# eksctl 이 만든 SA 를 그대로 사용 (create=false 가 핵심)
# --wait: 파드가 Ready 될 때까지 helm 이 대기 (webhook race 방지)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait --timeout 10m

# LBC 는 Service 를 가로채는 mutating webhook 을 등록합니다.
# 엔드포인트가 붙기 전에 다음 차트가 Service 를 만들면
# "no endpoints available for service aws-load-balancer-webhook-service" 로 실패하므로
# webhook 이 실제로 응답 가능해질 때까지 대기합니다.
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m

# 차트는 설치/업그레이드마다 self-signed CA 를 재발급해 Secret 과 webhook caBundle 에 심습니다.
# 기존 파드는 예전 인증서를 들고 있어 caBundle 과 어긋나면
# "x509: certificate signed by unknown authority" 로 webhook 호출이 실패합니다.
# 파드를 재시작해 현재 Secret 의 인증서를 다시 읽게 합니다.
kubectl -n kube-system rollout restart deploy/aws-load-balancer-controller
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m

echo "waiting for LBC webhook endpoints..."
for i in $(seq 1 60); do
  EPS=$(kubectl -n kube-system get endpoints aws-load-balancer-webhook-service \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
  if [ -n "$EPS" ]; then
    echo "webhook endpoints ready: $EPS"
    break
  fi
  sleep 5
done
[ -n "$EPS" ] || { echo "!!! LBC webhook endpoints not ready"; exit 1; }

# 엔드포인트가 붙어도 TLS 가 어긋나면 webhook 호출이 실패합니다.
# --dry-run=server 는 아무것도 만들지 않고 webhook 만 실제로 태워보는 검사입니다.
echo "probing webhook (server-side dry-run)..."
WEBHOOK_OK=""
for i in $(seq 1 30); do
  if kubectl create service clusterip webhook-probe --tcp=80:80 \
       --dry-run=server -o name >/dev/null 2>&1; then
    WEBHOOK_OK=yes
    echo "webhook responding correctly"
    break
  fi
  sleep 5
done
[ -n "$WEBHOOK_OK" ] || {
  echo "!!! LBC webhook not serving correctly. 확인:"
  echo "  kubectl -n kube-system logs deploy/aws-load-balancer-controller"
  exit 1
}

# ---- Namespaces ----
kubectl apply -f 00-namespaces.yaml

# ---- Loki (Single Binary) ----
# --wait: Loki 가 Ready 된 뒤 OTel 을 띄워야 exporter 연결 실패가 안 남
helm upgrade --install o11y-loki grafana/loki -n monitoring -f loki-values.yaml --wait --timeout 10m

# ---- OTel Collector (DaemonSet, raw manifest = 이름 o11y-otel 고정) ----
kubectl apply -f 20-otel.yaml

# ---- App (ECR 이미지 / TG ARN / ALB SG 치환 후 배포) ----
sed -e "s#__ECR_URL__#${ECR_URL}#g" \
    -e "s#__APP_TG_ARN__#${APP_TG_ARN}#g" \
    -e "s#__ALB_SG_ID__#${ALB_SG_ID}#g" \
    10-app.yaml | kubectl apply -f -

# ---- Grafana (선수등록번호 치환) ----
sed "s/__NN__/${COMPETITOR}/g" grafana-values.yaml > /tmp/grafana-values.rendered.yaml
helm upgrade --install o11y-grafana grafana/grafana -n monitoring -f /tmp/grafana-values.rendered.yaml

# ---- Grafana TargetGroupBinding (Service 생성 후) ----
kubectl -n monitoring rollout status deploy/o11y-grafana --timeout=5m
sed -e "s#__GRAFANA_TG_ARN__#${GRAFANA_TG_ARN}#g" \
    -e "s#__ALB_SG_ID__#${ALB_SG_ID}#g" \
    30-grafana-tgb.yaml | kubectl apply -f -

# ---- 로그 트래픽 생성기 (최근 로그가 항상 존재하도록) ----
kubectl apply -f 40-traffic.yaml

echo
echo "=== 배포 완료. 타깃 등록까지 1~2분 ==="
kubectl get targetgroupbindings -A
echo "App ALB    : http://$(aws elbv2 describe-load-balancers --names o11y-app-alb --query 'LoadBalancers[0].DNSName' --output text)"
echo "Grafana ALB: http://$(aws elbv2 describe-load-balancers --names o11y-grafana-alb --query 'LoadBalancers[0].DNSName' --output text)"
echo "Grafana 계정: skills${COMPETITOR} / GoodJob!Skills${COMPETITOR}^^"
