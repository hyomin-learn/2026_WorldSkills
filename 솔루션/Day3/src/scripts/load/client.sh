#!/bin/bash

REGION_CODE="ap-northeast-2"
SECRET_NAME="apdev-rds-proxy-secrets"
IMAGE="/home/ec2-user/worldskills.jpg"
LOG="app.log"
REQUEST_ID="$(date +%s%N)"
UUID="$(uuidgen)"
USERNAME="dbdump500001"
EMAIL="dbdump500001@example.org"
PRODUCT_ID="dbdump500001"

CF_ID=$(aws resourcegroupstaggingapi get-resources --tag-filters Key=Name,Values=apdev-cdn --resource-type-filters cloudfront --region us-east-1 --query 'ResourceTagMappingList[0].ResourceARN' --output text | sed 's:.*/::')
CF_DOMAIN=$(aws cloudfront get-distribution --id "$CF_ID" --query 'Distribution.DomainName' --output text)
URL="https://$CF_DOMAIN"

SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region "$REGION_CODE" --query SecretString --output text)
DB_USER=$(jq -r '.username' <<< "$SECRET")
DB_PASSWORD=$(jq -r '.password' <<< "$SECRET")
DB_HOST=$(jq -r '.proxy_host' <<< "$SECRET")
DB_PORT=$(jq -r '.proxy_port // 3306' <<< "$SECRET")
DB_NAME=$(jq -r '.dbname' <<< "$SECRET")

USER_POST="{\"requestid\":\"$REQUEST_ID\",\"uuid\":\"$UUID\",\"username\":\"$USERNAME\",\"email\":\"$EMAIL\"}"
PRODUCT_POST="{\"requestid\":\"$REQUEST_ID\",\"uuid\":\"$UUID\",\"id\":\"$PRODUCT_ID\",\"name\":\"dbdump500001\",\"price\":1234}"
PRODUCT_PUT="{\"requestid\":\"$REQUEST_ID\",\"uuid\":\"$UUID\",\"id\":\"$PRODUCT_ID\",\"name\":\"modified-product\",\"price\":2500}"
STRESS_POST="{\"requestid\":\"$REQUEST_ID\",\"uuid\":\"$UUID\",\"length\":256}"
FORMAT='HTTP:%{http_code} DNS:%{time_namelookup}s CONNECT:%{time_connect}s TTFB:%{time_starttransfer}s TOTAL:%{time_total}s\n'

request() {
  echo "[$1]" >> "$LOG"
  shift
  curl -sS -o /dev/null -w "$FORMAT" --connect-timeout 5 --max-time 10 "$@" >> "$LOG" 2>&1
}

cleanup() {
  MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -P "$DB_PORT" -D "$DB_NAME" -e "DELETE FROM user WHERE email='$EMAIL'; DELETE FROM product WHERE id='$PRODUCT_ID';" >/dev/null 2>&1
}

while true; do
  echo "===== $(date '+%F %T') =====" >> "$LOG"
  cleanup

  request "POST USER" -X POST -H "Content-Type: application/json" -d "$USER_POST" "$URL/v1/user"
  request "GET USER" "$URL/v1/user?email=$EMAIL&requestid=$REQUEST_ID&uuid=$UUID"

  request "POST PRODUCT" -X POST -H "Content-Type: application/json" -d "$PRODUCT_POST" "$URL/v1/product"
  request "GET PRODUCT" "$URL/v1/product?id=$PRODUCT_ID&requestid=$REQUEST_ID&uuid=$UUID"
  request "PUT PRODUCT" -X PUT -H "Content-Type: application/json" -d "$PRODUCT_PUT" "$URL/v1/product"
  request "PUT PRODUCT IMAGE" -X PUT -F "requestid=$REQUEST_ID" -F "uuid=$UUID" -F "id=$PRODUCT_ID" -F "file=@$IMAGE" "$URL/v1/product"

  request "POST STRESS" -X POST -H "Content-Type: application/json" -d "$STRESS_POST" "$URL/v1/stress"

  cleanup
  sleep 10
done