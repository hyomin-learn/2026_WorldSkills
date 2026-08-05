#!/bin/bash
set -x

# Make sure the SSM agent registers as early as possible, independent of
# everything else below (which can be slow / can fail without blocking this).
systemctl enable amazon-ssm-agent || true
systemctl restart amazon-ssm-agent || true

CURL="curl -fsSL --retry 5 --retry-delay 5 --connect-timeout 15 --max-time 300"

dnf install -y java-11-amazon-corretto-headless

KAFKA_VERSION="3.6.0"
SCALA_VERSION="2.13"
KAFKA_DIR="/opt/kafka"

mkdir -p "$KAFKA_DIR"
$CURL -o /tmp/kafka.tgz "https://archive.apache.org/dist/kafka/$${KAFKA_VERSION}/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz"
tar -xzf /tmp/kafka.tgz -C "$KAFKA_DIR" --strip-components=1

$CURL -o "$KAFKA_DIR/libs/aws-msk-iam-auth.jar" \
  "https://github.com/aws/aws-msk-iam-auth/releases/download/v2.2.0/aws-msk-iam-auth-2.2.0-all.jar"

cat > "$KAFKA_DIR/config/client-iam.properties" <<PROPS
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
PROPS

mkdir -p /opt/app
REGION="$(curl -fsS --connect-timeout 5 --max-time 10 http://169.254.169.254/latest/meta-data/placement/region || echo "${aws_region}")"
for i in 1 2 3 4 5; do
  aws s3 cp "s3://${app_bucket_name}/${app_object_key}" /opt/app/app --region "$REGION" && break
  sleep 10
done
chmod +x /opt/app/app

cat > /etc/systemd/system/sensor-producer.service <<UNIT
[Unit]
Description=WSC2026 Sensor Producer
After=network.target

[Service]
Type=simple
Environment=BOOTSTRAP_SERVERS=${bootstrap_brokers_plaintext}
Environment=TOPIC_RAW=${raw_topic_name}
ExecStart=/opt/app/app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable sensor-producer.service
systemctl start sensor-producer.service
