#!/bin/bash

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="apdev-eks-cluster"

APP_ALB_SECURITY_GROUP_NAME="apdev-app-alb-sg"
MONITORING_ALB_SECURITY_GROUP_NAME="apdev-monitoring-alb-sg"

CLUSTER_YAML_PATH="/home/ec2-user/eks/cluster.yaml"

echo "========================================"
echo "Kube Setup Start"
echo "========================================"

if [ ! -f "$CLUSTER_YAML_PATH" ]; then
    echo "ERROR: $CLUSTER_YAML_PATH not found"
    exit 1
fi


# ============================================================
# 1. EKS Cluster
# ============================================================

echo "========================================"
echo "Creating EKS cluster"
echo "========================================"

eksctl create cluster -f "$CLUSTER_YAML_PATH"

if [ $? -ne 0 ]; then
    echo "ERROR: EKS cluster creation failed."
    exit 1
fi

aws eks --region "$REGION_CODE" update-kubeconfig \
  --name "$EKS_CLUSTER_NAME"

su - ec2-user -c \
  "aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME"

echo "EKS cluster created."


# ============================================================
# 2. Namespace
# ============================================================

echo "========================================"
echo "Creating namespaces"
echo "========================================"

kubectl create ns apdev \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create ns monitoring \
  --dry-run=client -o yaml | kubectl apply -f -


# ============================================================
# 3. Security Groups
# ============================================================

EKS_APP_NODE_GROUP_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters \
    "Name=description,Values=Communication between all nodes in the cluster" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region "$REGION_CODE")

echo "Node Security Group: $EKS_APP_NODE_GROUP_SECURITY_GROUP_ID"

if [ -z "$EKS_APP_NODE_GROUP_SECURITY_GROUP_ID" ] || \
   [ "$EKS_APP_NODE_GROUP_SECURITY_GROUP_ID" = "None" ]; then

    echo "ERROR: EKS Node Security Group을 찾지 못했습니다."
    exit 1
fi


EKS_CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text \
  --region "$REGION_CODE")

echo "Cluster Security Group: $EKS_CLUSTER_SECURITY_GROUP_ID"

if [ -z "$EKS_CLUSTER_SECURITY_GROUP_ID" ] || \
   [ "$EKS_CLUSTER_SECURITY_GROUP_ID" = "None" ]; then

    echo "ERROR: EKS Cluster Security Group을 찾지 못했습니다."
    exit 1
fi


echo "========================================"
echo "Configuring EKS Security Groups"
echo "========================================"

aws ec2 authorize-security-group-ingress \
  --group-id "$EKS_CLUSTER_SECURITY_GROUP_ID" \
  --protocol -1 \
  --source-group "$EKS_APP_NODE_GROUP_SECURITY_GROUP_ID" \
  --region "$REGION_CODE" \
  > /dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "$EKS_APP_NODE_GROUP_SECURITY_GROUP_ID" \
  --protocol -1 \
  --source-group "$EKS_CLUSTER_SECURITY_GROUP_ID" \
  --region "$REGION_CODE" \
  > /dev/null 2>&1 || true

sleep 20


# ============================================================
# 4. Karpenter
# ============================================================

echo "========================================"
echo "Configuring Karpenter"
echo "========================================"

kubectl patch deployment karpenter \
  -n karpenter \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/replicas", "value": 1},
    {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
    {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {
      "key": "dedicated",
      "operator": "Equal",
      "value": "addon",
      "effect": "NoSchedule"
    }}
  ]' || true

/home/ec2-user/scripts/config/karpenter-tag.sh

KARPENTER_ROLE_NAME=$(aws iam list-roles \
  --query 'Roles[].RoleName' \
  --output text \
  | tr '\t' '\n' \
  | grep -i karpenter \
  | head -n 1 || true)

if [ -z "$KARPENTER_ROLE_NAME" ]; then
    echo "ERROR: Karpenter IAM Role을 찾지 못했습니다."
    exit 1
fi

echo "Karpenter IAM Role: $KARPENTER_ROLE_NAME"

aws iam attach-role-policy \
  --role-name "$KARPENTER_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
  > /dev/null 2>&1 || true

# 원본 파일을 직접 오염시키지 않도록 임시 파일 사용
KARPENTER_MANIFEST="/tmp/karpenter.yaml"

sed \
  "s|KARPENTER_ROLE_NAME|$KARPENTER_ROLE_NAME|g" \
  /home/ec2-user/eks/manifest/karpenter.yaml \
  > "$KARPENTER_MANIFEST"

kubectl apply -f "$KARPENTER_MANIFEST"

sleep 20

kubectl get pods -n karpenter || true


# ============================================================
# 5. CoreDNS
# ============================================================

echo "========================================"
echo "Configuring CoreDNS"
echo "========================================"

kubectl patch deployment coredns \
  -n kube-system \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/replicas", "value": 1},
    {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
    {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {
      "key": "dedicated",
      "operator": "Equal",
      "value": "addon",
      "effect": "NoSchedule"
    }}
  ]' || true


# ============================================================
# 6. Metrics Server
# ============================================================

echo "========================================"
echo "Configuring Metrics Server"
echo "========================================"

kubectl patch deployment metrics-server \
  -n kube-system \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/replicas", "value": 1},
    {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
    {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {
      "key": "dedicated",
      "operator": "Equal",
      "value": "addon",
      "effect": "NoSchedule"
    }}
  ]' || true


# ============================================================
# 7. Product ServiceAccount
# ============================================================

echo "========================================"
echo "Creating Product ServiceAccount"
echo "========================================"

eksctl create iamserviceaccount \
  --name apdev-product-sa \
  --region="$REGION_CODE" \
  --cluster "$EKS_CLUSTER_NAME" \
  --namespace=apdev \
  --attach-policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess" \
  --override-existing-serviceaccounts \
  --approve


# ============================================================
# 8. Application Configuration
# ============================================================

echo "========================================"
echo "Deploying Application Configuration"
echo "========================================"

kubectl apply \
  -f /home/ec2-user/eks/manifest/configmap.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/secrets.yaml


# ============================================================
# 9. User Application
# ============================================================

echo "========================================"
echo "Deploying User Application"
echo "========================================"

kubectl apply \
  -f /home/ec2-user/eks/manifest/user/hpa.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/user/deployment.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/user/service.yaml


# ============================================================
# 10. Product Application
# ============================================================

echo "========================================"
echo "Deploying Product Application"
echo "========================================"

kubectl apply \
  -f /home/ec2-user/eks/manifest/product/configmap.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/product/hpa.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/product/deployment.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/product/service.yaml


# ============================================================
# 11. Stress Application
# ============================================================

echo "========================================"
echo "Deploying Stress Application"
echo "========================================"

kubectl apply \
  -f /home/ec2-user/eks/manifest/stress/hpa.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/stress/deployment.yaml

kubectl apply \
  -f /home/ec2-user/eks/manifest/stress/service.yaml


# ============================================================
# 12. AWS Load Balancer Controller
# ============================================================

echo "========================================"
echo "Installing AWS Load Balancer Controller"
echo "========================================"

helm repo add eks \
  https://aws.github.io/eks-charts \
  2>/dev/null || true

helm repo update eks

helm upgrade -i aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$EKS_CLUSTER_NAME" \
  -f /home/ec2-user/eks/manifest/ingress/values.yaml

echo "Waiting for AWS Load Balancer Controller..."

if ! kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=5m; then

    echo "ERROR: AWS Load Balancer Controller is not ready."
    kubectl get pods -n kube-system
    exit 1
fi

echo "AWS Load Balancer Controller is ready."


# ============================================================
# 13. Application ALB
# ============================================================

echo "========================================"
echo "Creating Application ALB Ingress"
echo "========================================"

APP_ALB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters \
    "Name=group-name,Values=$APP_ALB_SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$REGION_CODE")

echo "APP ALB Security Group: $APP_ALB_SECURITY_GROUP_ID"

if [ -z "$APP_ALB_SECURITY_GROUP_ID" ] || \
   [ "$APP_ALB_SECURITY_GROUP_ID" = "None" ]; then

    echo "ERROR: APP ALB Security Group을 찾지 못했습니다."
    exit 1
fi


aws ec2 authorize-security-group-ingress \
  --group-id "$EKS_CLUSTER_SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 8080 \
  --source-group "$APP_ALB_SECURITY_GROUP_ID" \
  --region "$REGION_CODE" \
  > /dev/null 2>&1 || true


# 원본 ingress.yaml 수정하지 않고 임시 파일 생성
APP_INGRESS_MANIFEST="/tmp/app-ingress.yaml"

sed \
  "s|SECURITY_GROUP_ID|$APP_ALB_SECURITY_GROUP_ID|g" \
  /home/ec2-user/eks/manifest/ingress/ingress.yaml \
  > "$APP_INGRESS_MANIFEST"

kubectl apply -f "$APP_INGRESS_MANIFEST"

echo "Application Ingress created."

sleep 20


# ============================================================
# 14. Monitoring ALB
# ============================================================

echo "========================================"
echo "Configuring Monitoring ALB"
echo "========================================"

MONITORING_ALB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters \
    "Name=group-name,Values=$MONITORING_ALB_SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$REGION_CODE")

echo "Monitoring ALB Security Group: $MONITORING_ALB_SECURITY_GROUP_ID"

if [ -z "$MONITORING_ALB_SECURITY_GROUP_ID" ] || \
   [ "$MONITORING_ALB_SECURITY_GROUP_ID" = "None" ]; then

    echo "ERROR: Monitoring ALB Security Group을 찾지 못했습니다."
    exit 1
fi


aws ec2 authorize-security-group-ingress \
  --group-id "$EKS_CLUSTER_SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 3000 \
  --source-group "$MONITORING_ALB_SECURITY_GROUP_ID" \
  --region "$REGION_CODE" \
  > /dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "$EKS_CLUSTER_SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 9090 \
  --source-group "$MONITORING_ALB_SECURITY_GROUP_ID" \
  --region "$REGION_CODE" \
  > /dev/null 2>&1 || true


# ============================================================
# 15. Monitoring Ingress
# ============================================================

echo "========================================"
echo "Creating Monitoring Ingress"
echo "========================================"

GRAFANA_INGRESS_MANIFEST="/tmp/grafana-ingress.yaml"
PROMETHEUS_INGRESS_MANIFEST="/tmp/prometheus-ingress.yaml"

sed \
  "s|SECURITY_GROUP_ID|$MONITORING_ALB_SECURITY_GROUP_ID|g" \
  /home/ec2-user/eks/manifest/grafana/ingress.yaml \
  > "$GRAFANA_INGRESS_MANIFEST"

sed \
  "s|SECURITY_GROUP_ID|$MONITORING_ALB_SECURITY_GROUP_ID|g" \
  /home/ec2-user/eks/manifest/prometheus/ingress.yaml \
  > "$PROMETHEUS_INGRESS_MANIFEST"

kubectl apply -f "$PROMETHEUS_INGRESS_MANIFEST"
kubectl apply -f "$GRAFANA_INGRESS_MANIFEST"

echo "Monitoring Ingress created."

sleep 10


# ============================================================
# 16. OIDC Provider
# ============================================================

echo "========================================"
echo "Configuring OIDC"
echo "========================================"

eksctl utils associate-iam-oidc-provider \
  --region "$REGION_CODE" \
  --cluster "$EKS_CLUSTER_NAME" \
  --approve


# ============================================================
# 17. EBS CSI Driver
# ============================================================

echo "========================================"
echo "Installing EBS CSI Driver"
echo "========================================"

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --region "$REGION_CODE" \
  --cluster "$EKS_CLUSTER_NAME" \
  --namespace kube-system \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --region "$REGION_CODE" \
  --cluster "$EKS_CLUSTER_NAME" \
  --service-account-role-arn \
  "arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole" \
  --force

sleep 20


# ============================================================
# 18. EBS CSI Controller
# ============================================================

kubectl patch deployment ebs-csi-controller \
  -n kube-system \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/replicas", "value": 1},
    {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
    {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {
      "key": "dedicated",
      "operator": "Equal",
      "value": "addon",
      "effect": "NoSchedule"
    }}
  ]' || true


# ============================================================
# 19. EBS CSI Node
# ============================================================

kubectl patch daemonset ebs-csi-node \
  -n kube-system \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
    {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {
      "key": "dedicated",
      "operator": "Equal",
      "value": "addon",
      "effect": "NoSchedule"
    }}
  ]' || true

sleep 10


# ============================================================
# 20. Prometheus
# ============================================================

echo "========================================"
echo "Installing Prometheus"
echo "========================================"

kubectl apply \
  -f /home/ec2-user/eks/manifest/prometheus/sc.yaml

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  2>/dev/null || true

helm repo update

helm upgrade -i prometheus \
  prometheus-community/prometheus \
  -n monitoring \
  -f /home/ec2-user/eks/manifest/prometheus/values.yaml

sleep 30

APP_ALB_ID=$(aws elbv2 describe-load-balancers --name "apdev-app-alb" --query "LoadBalancers[0].LoadBalancerArn" --output text | cut -d: -f6- | sed 's/^loadbalancer\///')
USER_TARGET_GROUP_ID=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'apdev-apdevuse')].TargetGroupArn" --output text | cut -d: -f6-)
PRODUCT_TARGET_GROUP_ID=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'apdev-apdevpro')].TargetGroupArn" --output text | cut -d: -f6-)
STRESS_TARGET_GROUP_ID=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'apdev-apdevstr')].TargetGroupArn" --output text | cut -d: -f6-)

GRAFANA_DASHBOARD_JSON_PATH=$(sudo find / -name "dashboard.json")

sed -i "s|app/apdev-app-alb/c5689ad594f78fcc|$APP_ALB_ID|g" $GRAFANA_DASHBOARD_JSON_PATH
sed -i "s|targetgroup/k8s-apdev-apdevuse-fe498a4869/ff5690641dc18b79|$USER_TARGET_GROUP_ID|g" $GRAFANA_DASHBOARD_JSON_PATH
sed -i "s|targetgroup/k8s-apdev-apdevpro-db7c38740b/3a81d0758378301e|$PRODUCT_TARGET_GROUP_ID|g" $GRAFANA_DASHBOARD_JSON_PATH
sed -i "s|targetgroup/k8s-apdev-apdevstr-35cdc3c31d/d9ee6529fa41a5c3|$STRESS_TARGET_GROUP_ID|g" $GRAFANA_DASHBOARD_JSON_PATH

kubectl get pods -n monitoring


# ============================================================
# 21. S3 Bucket
# ============================================================

echo "========================================"
echo "Configuring Grafana S3"
echo "========================================"

S3_BUCKET_NAME=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'apdev-logs')].Name | [0]" \
  --output text \
  --region "$REGION_CODE")

if [ -z "$S3_BUCKET_NAME" ] || \
   [ "$S3_BUCKET_NAME" = "None" ]; then

    echo "ERROR: apdev-logs S3 Bucket을 찾지 못했습니다."
    exit 1
fi

echo "S3 Bucket: $S3_BUCKET_NAME"


# 원본 values.yaml 수정하지 않음
GRAFANA_VALUES="/tmp/grafana-values.yaml"

sed \
  "s|S3_BUCKET_NAME|$S3_BUCKET_NAME|g" \
  /home/ec2-user/eks/manifest/grafana/values.yaml \
  > "$GRAFANA_VALUES"


# ============================================================
# 22. Grafana ServiceAccount
# ============================================================

echo "========================================"
echo "Creating Grafana ServiceAccount"
echo "========================================"

eksctl create iamserviceaccount \
  --name apdev-grafana-sa \
  --region="$REGION_CODE" \
  --cluster "$EKS_CLUSTER_NAME" \
  --namespace=monitoring \
  --attach-policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" \
  --override-existing-serviceaccounts \
  --approve


# ============================================================
# 23. Grafana
# ============================================================

echo "========================================"
echo "Installing Grafana"
echo "========================================"

helm repo add grafana-community \
  https://grafana-community.github.io/helm-charts \
  2>/dev/null || true

helm repo update

helm upgrade -i grafana \
  grafana-community/grafana \
  -n monitoring \
  -f "$GRAFANA_VALUES"

echo "Waiting for Grafana deployment..."

if ! kubectl rollout status deployment/grafana \
  -n monitoring \
  --timeout=5m; then

    echo "WARNING: Grafana deployment rollout failed."
    kubectl get pods -n monitoring
else
    echo "Grafana deployment is ready."
fi


# ============================================================
# 24. Grafana Pod
# ============================================================

GRAFANA_POD=""

for i in $(seq 1 30); do

    GRAFANA_POD=$(kubectl get pod \
      -n monitoring \
      -l app.kubernetes.io/name=grafana \
      -o jsonpath='{.items[0].metadata.name}' \
      2>/dev/null || true)

    if [ -n "$GRAFANA_POD" ]; then
        break
    fi

    echo "Waiting for Grafana Pod... ($i/30)"
    sleep 2
done

if [ -z "$GRAFANA_POD" ]; then

    echo "WARNING: Grafana Pod을 찾지 못했습니다."
    kubectl get pods -n monitoring

else

    echo "Grafana Pod: $GRAFANA_POD"


    # ========================================================
    # 25. Grafana Password
    # ========================================================

    echo "========================================"
    echo "Getting Grafana Admin Password"
    echo "========================================"

    GRAFANA_PASSWORD=""

    for i in $(seq 1 30); do

        GRAFANA_PASSWORD=$(kubectl get secret grafana \
          -n monitoring \
          -o jsonpath="{.data.admin-password}" \
          2>/dev/null \
          | base64 --decode \
          2>/dev/null || true)

        if [ -n "$GRAFANA_PASSWORD" ]; then
            break
        fi

        echo "Waiting for Grafana Secret... ($i/30)"
        sleep 2
    done

    if [ -z "$GRAFANA_PASSWORD" ]; then

        echo "WARNING: Grafana admin password를 가져오지 못했습니다."

    else

        echo "Grafana admin password retrieved."


        # ====================================================
        # 26. Grafana Port Forward
        # ====================================================

        echo "========================================"
        echo "Starting Grafana Port Forward"
        echo "========================================"

        GRAFANA_LOCAL_PORT=13000

        kubectl port-forward \
          -n monitoring \
          "pod/$GRAFANA_POD" \
          "$GRAFANA_LOCAL_PORT:3000" \
          >/tmp/grafana-port-forward.log 2>&1 &

        GRAFANA_PF_PID=$!

        echo "Grafana Port Forward PID: $GRAFANA_PF_PID"

        GRAFANA_READY="false"

        for i in $(seq 1 30); do

            if curl -s \
              "http://127.0.0.1:$GRAFANA_LOCAL_PORT/api/health" \
              >/tmp/grafana-health.json 2>/dev/null; then

                echo "Grafana port-forward is ready."
                GRAFANA_READY="true"
                break
            fi

            echo "Waiting for Grafana port-forward... ($i/30)"
            sleep 2
        done


        if [ "$GRAFANA_READY" = "true" ]; then

            # =================================================
            # 27. Grafana API
            # =================================================

            GRAFANA_API_READY="false"

            for i in $(seq 1 30); do

                HEALTH_RESPONSE=$(curl -s \
                  -u "admin:$GRAFANA_PASSWORD" \
                  "http://127.0.0.1:$GRAFANA_LOCAL_PORT/api/health" \
                  2>/dev/null || true)

                echo "$HEALTH_RESPONSE" \
                  > /tmp/grafana-health.json

                # database 상태뿐만 아니라 HTTP 응답 자체를 확인
                if echo "$HEALTH_RESPONSE" | grep -qE '"database":[[:space:]]*"ok"'; then

                    echo "Grafana API is ready."
                    GRAFANA_API_READY="true"
                    break
                fi

                echo "Waiting for Grafana API... ($i/30)"
                sleep 2
            done


            if [ "$GRAFANA_API_READY" = "true" ]; then

                # =================================================
                # 28. Grafana Dashboard
                # =================================================

                DASHBOARD_FILE="/home/ec2-user/eks/manifest/grafana/dashboard.json"
                DASHBOARD_NAME="apdev-dashboard"
                DASHBOARD_API_BASE="http://127.0.0.1:$GRAFANA_LOCAL_PORT/apis/dashboard.grafana.app/v2beta1/namespaces/default/dashboards"

                echo "========================================"
                echo "Creating / Updating Grafana Dashboard"
                echo "========================================"

                if [ ! -f "$DASHBOARD_FILE" ]; then
                    echo "ERROR: dashboard.json not found: $DASHBOARD_FILE"
                elif ! jq empty "$DASHBOARD_FILE" >/dev/null 2>&1; then
                    echo "ERROR: dashboard.json is invalid JSON"
                else
                    PANEL_COUNT=$(jq '.spec.elements // [] | length' "$DASHBOARD_FILE")
                    DASHBOARD_TITLE=$(jq -r '.spec.title // "apdev-dashboard"' "$DASHBOARD_FILE")

                    echo "Dashboard name : $DASHBOARD_NAME"
                    echo "Dashboard title: $DASHBOARD_TITLE"
                    echo "Element count  : $PANEL_COUNT"

                    if [ "$PANEL_COUNT" -le 0 ]; then
                        echo "ERROR: dashboard.json contains no dashboard elements."
                    else
                        # Grafana 13 new Dashboard API expects metadata + spec.
                        # Remove server-generated metadata (uid/resourceVersion/etc.)
                        # and keep only the dashboard specification.
                        jq -n \
                          --arg name "$DASHBOARD_NAME" \
                          --argjson spec "$(jq '.spec' "$DASHBOARD_FILE")" \
                          '{
                            metadata: {
                              name: $name,
                              namespace: "default"
                            },
                            spec: $spec
                          }' \
                          > /tmp/grafana-dashboard-payload.json

                        echo "Dashboard payload:" \
                        jq '{metadata,spec_title:.spec.title,elements:(.spec.elements|length)}' \
                          /tmp/grafana-dashboard-payload.json

                        # First check whether the dashboard already exists.
                        EXISTING_CODE=$(curl -sS \
                          -u "admin:$GRAFANA_PASSWORD" \
                          -o /tmp/grafana-dashboard-existing.json \
                          -w '%{http_code}' \
                          "$DASHBOARD_API_BASE/$DASHBOARD_NAME")

                        echo "Existing dashboard HTTP Status: $EXISTING_CODE"

                        if [ "$EXISTING_CODE" = "200" ]; then
                            echo "Dashboard already exists. Updating..."

                            HTTP_CODE=$(curl -sS \
                              -u "admin:$GRAFANA_PASSWORD" \
                              -X PUT \
                              -H 'Accept: application/json' \
                              -H 'Content-Type: application/json' \
                              --data-binary @/tmp/grafana-dashboard-payload.json \
                              -o /tmp/grafana-dashboard-response.json \
                              -w '%{http_code}' \
                              "$DASHBOARD_API_BASE/$DASHBOARD_NAME")

                        elif [ "$EXISTING_CODE" = "404" ]; then
                            echo "Dashboard does not exist. Creating..."

                            HTTP_CODE=$(curl -sS \
                              -u "admin:$GRAFANA_PASSWORD" \
                              -X POST \
                              -H 'Accept: application/json' \
                              -H 'Content-Type: application/json' \
                              --data-binary @/tmp/grafana-dashboard-payload.json \
                              -o /tmp/grafana-dashboard-response.json \
                              -w '%{http_code}' \
                              "$DASHBOARD_API_BASE")

                        else
                            echo "ERROR: Unable to check existing dashboard. HTTP $EXISTING_CODE"
                            cat /tmp/grafana-dashboard-existing.json 2>/dev/null || true
                            HTTP_CODE="$EXISTING_CODE"
                        fi

                        echo "Grafana Dashboard write HTTP Status: $HTTP_CODE"
                        echo "Grafana Dashboard response:"
                        cat /tmp/grafana-dashboard-response.json 2>/dev/null || true
                        echo

                        if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
                            echo "Dashboard write succeeded. Verifying..."

                            VERIFY_CODE=$(curl -sS \
                              -u "admin:$GRAFANA_PASSWORD" \
                              -o /tmp/grafana-dashboard-verify.json \
                              -w '%{http_code}' \
                              "$DASHBOARD_API_BASE/$DASHBOARD_NAME")

                            echo "Grafana Dashboard verify HTTP Status: $VERIFY_CODE"

                            if [ "$VERIFY_CODE" = "200" ]; then
                                VERIFIED_NAME=$(jq -r '.metadata.name // empty' /tmp/grafana-dashboard-verify.json)
                                VERIFIED_TITLE=$(jq -r '.spec.title // empty' /tmp/grafana-dashboard-verify.json)
                                VERIFIED_ELEMENTS=$(jq '.spec.elements // [] | length' /tmp/grafana-dashboard-verify.json)

                                echo "Verified dashboard name : $VERIFIED_NAME"
                                echo "Verified dashboard title: $VERIFIED_TITLE"
                                echo "Verified element count  : $VERIFIED_ELEMENTS"

                                if [ "$VERIFIED_NAME" = "$DASHBOARD_NAME" ] && \
                                   [ "$VERIFIED_ELEMENTS" -gt 0 ]; then
                                    echo "========================================"
                                    echo "Grafana Dashboard READY"
                                    echo "========================================"
                                else
                                    echo "ERROR: Dashboard verification failed."
                                fi
                            else
                                echo "ERROR: Dashboard was written but could not be verified."
                                cat /tmp/grafana-dashboard-verify.json 2>/dev/null || true
                            fi
                        else
                            echo "ERROR: Grafana Dashboard creation/update failed."
                            echo "The Kubernetes deployment itself is not stopped by this error."
                        fi
                    fi
                fi

            else

                echo "WARNING: Grafana API가 준비되지 않았습니다."
                echo "ALB/Ingress 생성에는 영향을 주지 않습니다."

                cat /tmp/grafana-health.json 2>/dev/null || true

            fi

        else

            echo "WARNING: Grafana port-forward가 준비되지 않았습니다."
            echo "ALB/Ingress 생성에는 영향을 주지 않습니다."

            cat /tmp/grafana-port-forward.log 2>/dev/null || true

        fi


        kill "$GRAFANA_PF_PID" 2>/dev/null || true

    fi

fi


# ============================================================
# 30. Final Status
# ============================================================

echo
echo "========================================"
echo "Final Kubernetes Status"
echo "========================================"

echo
echo "=== Nodes ==="
kubectl get nodes -o wide

echo
echo "=== Application Pods ==="
kubectl get pods -n apdev -o wide

echo
echo "=== Monitoring Pods ==="
kubectl get pods -n monitoring -o wide

echo
echo "=== Kube System Pods ==="
kubectl get pods -n kube-system

echo
echo "=== Ingress ==="
kubectl get ingress -A

echo
echo "========================================"
echo "Kube-setup 설정 완료"
echo "========================================"