import json
import os
import time
from datetime import datetime, timezone

import boto3

ec2_client = boto3.client("ec2")
sns_client = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")


def publish_alert(event_type, detail, action):
    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps({
            "event": event_type,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "detail": detail,
            "action": action,
        }),
    )


def _to_boto_ip_permissions(ip_permissions_raw):
    """CloudTrail 이벤트의 ipPermissions.items[] 구조를
    boto3 revoke_security_group_ingress()가 받는 IpPermissions 리스트로 변환한다."""
    permissions = []

    for perm in ip_permissions_raw:
        entry = {"IpProtocol": perm.get("ipProtocol")}

        if perm.get("fromPort") is not None:
            entry["FromPort"] = perm["fromPort"]
        if perm.get("toPort") is not None:
            entry["ToPort"] = perm["toPort"]

        ip_ranges = (perm.get("ipRanges") or {}).get("items", [])
        if ip_ranges:
            entry["IpRanges"] = [
                {"CidrIp": r["cidrIp"]} for r in ip_ranges if r.get("cidrIp")
            ]

        ipv6_ranges = (perm.get("ipv6Ranges") or {}).get("items", [])
        if ipv6_ranges:
            entry["Ipv6Ranges"] = [
                {"CidrIpv6": r["cidrIpv6"]} for r in ipv6_ranges if r.get("cidrIpv6")
            ]

        groups = (perm.get("groups") or {}).get("items", [])
        if groups:
            entry["UserIdGroupPairs"] = [
                {"GroupId": g["groupId"]} for g in groups if g.get("groupId")
            ]

        if entry.get("IpRanges") or entry.get("Ipv6Ranges") or entry.get("UserIdGroupPairs"):
            permissions.append(entry)

    return permissions


# ===== wsc2026-sg-remediation =====
def sg_remediation_handler(event, context):
    sg_id = os.environ.get("SECURITY_GROUP_ID")
    detail = event.get("detail", {})
    request_params = detail.get("requestParameters", {}) or {}

    ip_permissions_raw = (request_params.get("ipPermissions") or {}).get("items", [])
    ip_permissions = _to_boto_ip_permissions(ip_permissions_raw)

    if ip_permissions:
        try:
            ec2_client.revoke_security_group_ingress(
                GroupId=sg_id,
                IpPermissions=ip_permissions,
            )
        except ec2_client.exceptions.ClientError:
            # 이미 제거되었거나 존재하지 않는 규칙인 경우 무시
            pass

    publish_alert(
        "SG_INBOUND_ADDED",
        f"Unauthorized inbound rule removed from {sg_id}",
        "RESTORED",
    )


# ===== wsc2026-ec2-stop-remediation =====
def ec2_stop_remediation_handler(event, context):
    instance_id = os.environ.get("INSTANCE_ID")
    detail = event.get("detail", {})
    state = detail.get("state")

    if state in ("stopping", "stopped"):
        _wait_stopped_then_start(instance_id, context)

    publish_alert(
        "EC2_STOPPED",
        f"Instance {instance_id} was stopped and has been restarted",
        "RESTORED",
    )


def _wait_stopped_then_start(instance_id, context):
    """인스턴스가 실제로 stopped 상태가 되는 즉시 재시작한다.
    Lambda 남은 실행시간(5초 버퍼)을 넘기지 않는 선에서 짧은 간격으로 폴링한다."""
    poll_interval_sec = 3

    while context.get_remaining_time_in_millis() > 5000:
        try:
            resp = ec2_client.describe_instances(InstanceIds=[instance_id])
            current_state = resp["Reservations"][0]["Instances"][0]["State"]["Name"]
        except Exception:
            current_state = None

        if current_state == "stopped":
            try:
                ec2_client.start_instances(InstanceIds=[instance_id])
            except ec2_client.exceptions.ClientError:
                pass
            return

        if current_state == "running":
            # 이미 복구된 경우 (중복 이벤트 등)
            return

        time.sleep(poll_interval_sec)


# ===== wsc2026-ec2-terminate-alert =====
def ec2_terminate_handler(event, context):
    detail = event.get("detail", {})
    instance_id = detail.get("instance-id", "unknown")

    publish_alert(
        "EC2_TERMINATED",
        f"Instance {instance_id} termination detected",
        "ALERT_ONLY",
    )


# ===== wsc2026-tag-alert =====
def tag_alert_handler(event, context):
    detail = event.get("detail", {})
    config_rule_name = detail.get("configRuleName", "unknown")
    evaluation = detail.get("newEvaluationResult", {}) or {}
    compliance_type = evaluation.get("complianceType", "unknown")
    resource_id = (
        detail.get("resourceId")
        or detail.get("resourceType")
        or "unknown"
    )

    publish_alert(
        "REQUIRED_TAG_MISSING",
        f"{config_rule_name} reported {compliance_type} for resource {resource_id}",
        "ALERT_ONLY",
    )
