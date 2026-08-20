#!/bin/bash
REGION_CODE="ap-northeast-2"
CLOUD_FRONT_NAME="apdev-cdn"
URL_ENDPOINT=$(aws resourcegroupstaggingapi get-resources --tag-filters Key=Name,Values=$CLOUD_FRONT_NAME --resource-type-filters 'cloudfront' --region us-east-1 --query "ResourceTagMappingList[0].ResourceARN" --output text | sed 's:.*/::' | xargs -I {} aws cloudfront get-distribution --id {} --query "Distribution.DomainName" --output text)

SECRET_NAME="apdev-rds-secrets"
MYSQL_USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_USER")
MYSQL_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PASSWORD")
MYSQL_HOST=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_HOST")
MYSQL_PORT=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PORT")
MYSQL_DBNAME=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_DBNAME")

UUID="$(uuidgen)"
USER_EMAIL="dbdump500001@example.org"
PRODUCT_ID="dbdump500001"

CURL_FORMAT='\nWeb Site URL: %{url_effective}\n\nLookup Time:\t\t%{time_namelookup}\nConnect Time:\t\t%{time_connect}\nPre-transfer Time:\t%{time_pretransfer}\nStart-transfer Time:\t%{time_starttransfer}\n\nTotal Time:\t\t%{time_total}\n%{http_code}\n'

while :
do
    REQUEST_ID=$(uuidgen)

    USER_POST_BODY="{\"requestid\": \"$REQUEST_ID\", \"uuid\": \"$UUID\", \"username\": \"dbdump500001\", \"email\": \"$USER_EMAIL\"}"
    PRODUCT_POST_BODY="{\"requestid\": \"$REQUEST_ID\", \"uuid\": \"$UUID\", \"id\": \"$PRODUCT_ID\", \"name\": \"dbdump500001\", \"price\": 1234.0}"
    PRODUCT_PUT_BODY="{\"requestid\": \"$REQUEST_ID\", \"uuid\": \"$UUID\", \"id\": \"$PRODUCT_ID\"}"
    STRESS_POST_BODY="{\"requestid\": \"$REQUEST_ID\", \"uuid\": \"$UUID\", \"length\": 256}"

    echo "=========================================" >> app.log 2>&1
    echo "API TEST START: $(date)" >> app.log 2>&1
    echo "=========================================" >> app.log 2>&1

    echo "[1-1] POST /v1/user" >> app.log 2>&1
    curl -X POST -s -o /dev/null -w "$CURL_FORMAT" -H 'Content-Type: application/json' -d "$USER_POST_BODY" "$URL_ENDPOINT/v1/user" >> app.log 2>&1
    echo "---" >> app.log 2>&1
    
    echo "[1-2] GET /v1/user" >> app.log 2>&1
    curl -X GET -s -o /dev/null -w "$CURL_FORMAT" "$URL_ENDPOINT/v1/user?email=$USER_EMAIL&requestid=$REQUEST_ID&uuid=$UUID" >> app.log 2>&1
    echo "---" >> app.log 2>&1

    echo "[2-1] POST /v1/product" >> app.log 2>&1
    curl -X POST -s -o /dev/null -w "$CURL_FORMAT" -H 'Content-Type: application/json' -d "$PRODUCT_POST_BODY" "$URL_ENDPOINT/v1/product" >> app.log 2>&1
    echo "---" >> app.log 2>&1

    echo "[2-2] GET /v1/product" >> app.log 2>&1
    curl -X GET -s -o /dev/null -w "$CURL_FORMAT" "$URL_ENDPOINT/v1/product?id=$PRODUCT_ID&requestid=$REQUEST_ID&uuid=$UUID" >> app.log 2>&1
    echo "---" >> app.log 2>&1

    echo "[2-3] PUT /v1/product" >> app.log 2>&1
    curl -X PUT -s -o /dev/null -w "$CURL_FORMAT" -H 'Content-Type: application/json' -d "$PRODUCT_PUT_BODY" "$URL_ENDPOINT/v1/product" >> app.log 2>&1
    echo "---" >> app.log 2>&1

    echo "[3] POST /v1/stress" >> app.log 2>&1
    curl -X POST -s -o /dev/null -w "$CURL_FORMAT" -H 'Content-Type: application/json' -d "$STRESS_POST_BODY" "$URL_ENDPOINT/v1/stress" >> app.log 2>&1
    echo "---" >> app.log 2>&1
    echo " " >> app.log 2>&1
    
    mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -P "$MYSQL_PORT" -p"$MYSQL_PASSWORD" -D "$MYSQL_DBNAME" -e "DELETE FROM \`user\` WHERE email='$USER_EMAIL';"
    mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -P "$MYSQL_PORT" -p"$MYSQL_PASSWORD" -D "$MYSQL_DBNAME" -e "DELETE FROM product WHERE id='$PRODUCT_ID';"

    sleep 10
done