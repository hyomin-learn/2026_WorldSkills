#!/bin/bash
set -euo pipefail

REGION_CODE="ap-northeast-2"
SECRET_NAME="apdev-rds-secrets"
PROXY_NAME="apdev-rds-proxy"

SECRET_STRING=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --query "SecretString" \
  --output text \
  --region "$REGION_CODE")

MYSQL_USER=$(echo "$SECRET_STRING" | jq -r ".MYSQL_USER")
MYSQL_PASSWORD=$(echo "$SECRET_STRING" | jq -r ".MYSQL_PASSWORD")
MYSQL_DBNAME=$(echo "$SECRET_STRING" | jq -r ".MYSQL_DBNAME")
MYSQL_PORT="3306"

MYSQL_HOST=$(aws rds describe-db-proxies \
  --db-proxy-name "$PROXY_NAME" \
  --query "DBProxies[0].Endpoint" \
  --output text \
  --region "$REGION_CODE")

echo "RDS Proxy endpoint: $MYSQL_HOST"

sed -i "s|DB_USER|$MYSQL_USER|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_PASSWORD|$MYSQL_PASSWORD|g" /home/ec2-user/eks/manifest/secrets.yaml
sed -i "s|DB_HOST|$MYSQL_HOST|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_PORT|$MYSQL_PORT|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_NAME|$MYSQL_DBNAME|g" /home/ec2-user/eks/manifest/configmap.yaml

echo "Waiting for RDS Proxy target..."

for i in $(seq 1 60); do

    TARGET_STATUS=$(aws rds describe-db-proxy-targets \
      --db-proxy-name "$PROXY_NAME" \
      --query "Targets[0].TargetHealth.State" \
      --output text \
      --region "$REGION_CODE" 2>/dev/null || true)

    echo "Proxy Target: $TARGET_STATUS"

    if [ "$TARGET_STATUS" = "AVAILABLE" ]; then
        echo "RDS Proxy target is AVAILABLE."
        break
    fi

    sleep 10
done

if [ "$TARGET_STATUS" != "AVAILABLE" ]; then
    echo "ERROR: RDS Proxy target is not AVAILABLE."
    exit 1
fi

echo "Testing MySQL connection..."

# RDS Proxy가 새/갱신된 Secrets Manager 시크릿을 내부적으로 반영하는 데
# propagation 지연이 있을 수 있어(수 분 단위), 재시도를 넉넉하게 잡는다.
# (기존 30회 * 10초 = 최대 5분 -> 90회 * 10초 = 최대 15분)
MYSQL_CONNECT_LOG="/tmp/mysql-connect-error.log"

for i in $(seq 1 90); do

    if mysql \
      -h "$MYSQL_HOST" \
      -u "$MYSQL_USER" \
      -P "$MYSQL_PORT" \
      -p"$MYSQL_PASSWORD" \
      -e "SELECT 1;" >/dev/null 2>"$MYSQL_CONNECT_LOG"
    then
        echo "MySQL connection successful."
        break
    fi

    echo "MySQL connection failed. Retry after 10 seconds... ($i/90)"
    tail -n 1 "$MYSQL_CONNECT_LOG" 2>/dev/null || true
    sleep 10
done

if ! mysql \
  -h "$MYSQL_HOST" \
  -u "$MYSQL_USER" \
  -P "$MYSQL_PORT" \
  -p"$MYSQL_PASSWORD" \
  -e "SELECT 1;" >/dev/null 2>"$MYSQL_CONNECT_LOG"
then
    echo "ERROR: Cannot connect to RDS Proxy."
    echo "마지막 mysql 에러 메시지:"
    cat "$MYSQL_CONNECT_LOG" 2>/dev/null || true
    exit 1
fi

echo "Loading dump.sql..."

mysql \
  -h "$MYSQL_HOST" \
  -u "$MYSQL_USER" \
  -P "$MYSQL_PORT" \
  -p"$MYSQL_PASSWORD" \
  -D "$MYSQL_DBNAME" \
  < /home/ec2-user/rds/dump.sql

echo "dump.sql applied"