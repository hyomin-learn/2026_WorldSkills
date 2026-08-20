#!/bin/bash
REGION_CODE="ap-northeast-2"
SECRET_NAME="apdev-rds-secrets"
MYSQL_USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_USER")
MYSQL_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PASSWORD")
MYSQL_HOST=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_HOST")
MYSQL_PORT=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PORT")
MYSQL_DBNAME=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_DBNAME")

while :
do
    mysql -h $MYSQL_HOST -u $MYSQL_USER -P $MYSQL_PORT -p$MYSQL_PASSWORD -D $MYSQL_DBNAME -e "SELECT * FROM information_schema.processlist  WHERE COMMAND = 'Sleep' AND USER NOT LIKE '%rds%' AND USER NOT LIKE '%event_scheduler%';"  | egrep 'Sleep|Lock' | awk '{print "kill "$1";"}' > /tmp/kill.txt
    mysql -h $MYSQL_HOST -u $MYSQL_USER -P $MYSQL_PORT -p$MYSQL_PASSWORD -D $MYSQL_DBNAME < /tmp/kill.txt
    mysql -h $MYSQL_HOST -u $MYSQL_USER -P $MYSQL_PORT -p$MYSQL_PASSWORD -D $MYSQL_DBNAME -e "SHOW processlist;"

    sleep 60
done