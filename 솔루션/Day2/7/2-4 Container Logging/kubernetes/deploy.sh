#!/bin/bash
set -e

: "${ECR_URL:?ECR_URL env not set (source ~/.bashrc)}"
: "${ALB_SG_ID:?ALB_SG_ID env not set (source ~/.bashrc)}"
: "${APP_TG_ARN:?APP_TG_ARN env not set (source ~/.bashrc)}"
: "${GRAFANA_TG_ARN:?GRAFANA_TG_ARN env not set (source ~/.bashrc)}"

COMPETITOR="${1:-$COMPETITOR}"
: "${COMPETITOR:?선수등록번호 없음. './deploy.sh 53' 처럼 인자로 주거나 source ~/.bashrc}"

cd "$(dirname "$0")"

helm repo add eks https://aws.github.io/eks-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

CLUSTER_NAME=$(kubectl config current-context | cut -d/ -f2)
REGION="${AWS_REGION:-ap-northeast-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" --region "$REGION" --approve || true

if ! aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy" >/dev/null 2>&1; then
  curl -sLo /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/iam-policy.json
fi

eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" --region "$REGION" \
  --namespace kube-system --name aws-load-balancer-controller \
  --attach-policy-arn "arn:aws:iam::$ACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts --approve || true

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait --timeout 10m

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m

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

kubectl apply -f 00-namespaces.yaml

helm upgrade --install o11y-loki grafana/loki -n monitoring -f loki-values.yaml --wait --timeout 10m

kubectl apply -f 20-otel.yaml

sed -e "s#__ECR_URL__#${ECR_URL}#g" \
    -e "s#__APP_TG_ARN__#${APP_TG_ARN}#g" \
    -e "s#__ALB_SG_ID__#${ALB_SG_ID}#g" \
    10-app.yaml | kubectl apply -f -

sed "s/__NN__/${COMPETITOR}/g" grafana-values.yaml > /tmp/grafana-values.rendered.yaml
helm upgrade --install o11y-grafana grafana/grafana -n monitoring -f /tmp/grafana-values.rendered.yaml

kubectl -n monitoring rollout status deploy/o11y-grafana --timeout=5m
sed -e "s#__GRAFANA_TG_ARN__#${GRAFANA_TG_ARN}#g" \
    -e "s#__ALB_SG_ID__#${ALB_SG_ID}#g" \
    30-grafana-tgb.yaml | kubectl apply -f -

kubectl apply -f 40-traffic.yaml

echo
echo "=== 배포 완료. 타깃 등록까지 1~2분 ==="
kubectl get targetgroupbindings -A
echo "App ALB    : http://$(aws elbv2 describe-load-balancers --names o11y-app-alb --query 'LoadBalancers[0].DNSName' --output text)"
echo "Grafana ALB: http://$(aws elbv2 describe-load-balancers --names o11y-grafana-alb --query 'LoadBalancers[0].DNSName' --output text)"
echo "Grafana 계정: skills${COMPETITOR} / GoodJob!Skills${COMPETITOR}^^"
