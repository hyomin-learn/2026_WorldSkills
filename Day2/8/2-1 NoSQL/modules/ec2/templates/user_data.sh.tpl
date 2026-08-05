#!/bin/bash
set -e
export AWS_DEFAULT_REGION=ap-northeast-2

dnf install -y python3-pip

mkdir -p /opt/skills-nosql

aws s3 cp "s3://${app_bucket}/${docdb_client_object_key}" /opt/skills-nosql/docdb_client.py
aws s3 cp "s3://${app_bucket}/${retail_dataset_object_key}" /opt/skills-nosql/retail_dataset.json

curl -s -o /opt/skills-nosql/global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

pip3 install boto3 pymongo

cat > /etc/systemd/system/skills-nosql-client.service <<'UNIT'
[Unit]
Description=Skills NoSQL DocumentDB Client Application
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/skills-nosql
ExecStart=/usr/bin/python3 /opt/skills-nosql/docdb_client.py serve
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now skills-nosql-client.service

cat > /opt/skills-nosql/create_indexes.py <<'PYEOF'
import sys
sys.path.insert(0, "/opt/skills-nosql")
from docdb_client import db

database = db()

database.orders.create_index([("orderId", 1)], unique=True)
database.orders.create_index([("customerId", 1), ("createdAt", -1)])
database.orders.create_index([("status", 1), ("dueAt", 1)])

database.products.create_index([("productId", 1)], unique=True)
database.products.create_index([("warehouseId", 1), ("stock", 1)])

database.sessions.create_index([("sessionId", 1)], unique=True)
database.sessions.create_index([("expiresAt", 1)], expireAfterSeconds=0)
database.sessions.create_index([("customerId", 1), ("lastSeen", -1)])

print("indexes ready")
PYEOF

for i in $(seq 1 20); do
  if /usr/bin/python3 /opt/skills-nosql/docdb_client.py health > /tmp/health.json 2>/tmp/health.err; then
    break
  fi
  sleep 15
done

/usr/bin/python3 /opt/skills-nosql/docdb_client.py seed
/usr/bin/python3 /opt/skills-nosql/create_indexes.py
