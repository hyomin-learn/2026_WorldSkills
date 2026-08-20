#!/bin/bash
set -uo pipefail
# kube-setup.sh 전체를 다시 돌리지 않고
# Grafana 대시보드 생성/갱신만 재실행하기 위한 스크립트.
# 반드시 values.yaml을 helm upgrade로 먼저 반영한 뒤에 실행할 것:
#
#   helm upgrade grafana grafana-community/grafana \
#     -n monitoring \
#     -f /home/ec2-user/eks/manifest/grafana/values.yaml
#
#   kubectl rollout status deployment/grafana -n monitoring
#
#   bash /home/ec2-user/scripts/config/grafana-dashboard-only.sh

# ============================================================
# Grafana Pod
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
    echo "ERROR: Grafana Pod을 찾지 못했습니다."
    kubectl get pods -n monitoring
    exit 1
fi

echo "Grafana Pod: $GRAFANA_POD"

# ============================================================
# Grafana Password
# ============================================================

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
    echo "ERROR: Grafana admin password를 가져오지 못했습니다."
    exit 1
fi

echo "Grafana admin password retrieved."

# ============================================================
# Grafana Port Forward
# ============================================================

GRAFANA_LOCAL_PORT=13000

# 이미 떠 있는 port-forward가 있으면 정리
pkill -f "port-forward.*pod/$GRAFANA_POD.*$GRAFANA_LOCAL_PORT" 2>/dev/null || true
sleep 1

kubectl port-forward \
  -n monitoring \
  "pod/$GRAFANA_POD" \
  "$GRAFANA_LOCAL_PORT:3000" \
  >/tmp/grafana-port-forward.log 2>&1 &

GRAFANA_PF_PID=$!
echo "Grafana Port Forward PID: $GRAFANA_PF_PID"

cleanup() {
    kill "$GRAFANA_PF_PID" 2>/dev/null || true
}
trap cleanup EXIT

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

if [ "$GRAFANA_READY" != "true" ]; then
    echo "ERROR: Grafana port-forward가 준비되지 않았습니다."
    exit 1
fi

# ============================================================
# Grafana API
# ============================================================

GRAFANA_API_READY="false"

for i in $(seq 1 30); do
    HEALTH_RESPONSE=$(curl -s \
      -u "admin:$GRAFANA_PASSWORD" \
      "http://127.0.0.1:$GRAFANA_LOCAL_PORT/api/health" \
      2>/dev/null || true)

    echo "$HEALTH_RESPONSE" > /tmp/grafana-health.json

    if echo "$HEALTH_RESPONSE" | grep -qE '"database":[[:space:]]*"ok"'; then
        echo "Grafana API is ready."
        GRAFANA_API_READY="true"
        break
    fi

    echo "Waiting for Grafana API... ($i/30)"
    sleep 2
done

if [ "$GRAFANA_API_READY" != "true" ]; then
    echo "ERROR: Grafana API가 준비되지 않았습니다."
    exit 1
fi

# ============================================================
# Grafana Dashboard
# ============================================================

DASHBOARD_FILE="/home/ec2-user/eks/manifest/grafana/dashboard.json"
DASHBOARD_NAME="apdev-dashboard"
DASHBOARD_API_BASE="http://127.0.0.1:$GRAFANA_LOCAL_PORT/apis/dashboard.grafana.app/v2beta1/namespaces/default/dashboards"

echo "========================================"
echo "Creating / Updating Grafana Dashboard"
echo "========================================"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "ERROR: dashboard.json not found: $DASHBOARD_FILE"
    exit 1
elif ! jq empty "$DASHBOARD_FILE" >/dev/null 2>&1; then
    echo "ERROR: dashboard.json is invalid JSON"
    exit 1
fi

PANEL_COUNT=$(jq '.spec.elements // [] | length' "$DASHBOARD_FILE")
DASHBOARD_TITLE=$(jq -r '.spec.title // "apdev-dashboard"' "$DASHBOARD_FILE")

echo "Dashboard name : $DASHBOARD_NAME"
echo "Dashboard title: $DASHBOARD_TITLE"
echo "Element count  : $PANEL_COUNT"

if [ "$PANEL_COUNT" -le 0 ]; then
    echo "ERROR: dashboard.json contains no dashboard elements."
    exit 1
fi

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

echo "Dashboard payload:"
jq '{metadata,spec_title:.spec.title,elements:(.spec.elements|length)}' \
  /tmp/grafana-dashboard-payload.json

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
        echo "SUCCESS: Grafana Dashboard가 정상적으로 생성/갱신되었습니다."
    else
        echo "WARNING: 저장은 됐지만 검증 조회에 실패했습니다. HTTP $VERIFY_CODE"
    fi
else
    echo "ERROR: Grafana Dashboard creation/update failed."
    exit 1
fi
