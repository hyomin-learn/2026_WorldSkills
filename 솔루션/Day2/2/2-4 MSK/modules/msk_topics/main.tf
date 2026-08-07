locals {
  is_windows = length(regexall("(?i)^[a-z]:", abspath(path.root))) > 0

  remote_cmd = <<-REMOTE
    set -e
    for i in $(seq 1 40); do
      [ -x /opt/kafka/bin/kafka-topics.sh ] && break
      sleep 15
    done
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server "${var.bootstrap_brokers_iam}" \
      --command-config /opt/kafka/config/client-iam.properties \
      --create --if-not-exists --topic "${var.raw_topic_name}" \
      --partitions ${var.raw_topic_partitions} --replication-factor ${var.raw_topic_replication_factor}
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server "${var.bootstrap_brokers_iam}" \
      --command-config /opt/kafka/config/client-iam.properties \
      --create --if-not-exists --topic "${var.alert_topic_name}" \
      --partitions ${var.alert_topic_partitions} --replication-factor ${var.alert_topic_replication_factor}
  REMOTE

  remote_cmd_b64 = base64encode(local.remote_cmd)

  # Writing the SSM --parameters payload to a real file avoids all of the
  # native-exe argument quoting problems that both bash and PowerShell have
  # with embedded double quotes (aws-cli requires --parameters file://...).
  params_path = replace(abspath("${path.module}/build/ssm_params_${var.raw_topic_name}.json"), "\\", "/")

  bash_script = <<-EOT
    set -e
    INSTANCE_ID="${var.ec2_instance_id}"
    REGION="${var.region}"

    echo "Waiting for SSM agent to come online on $INSTANCE_ID..."
    STATUS="Offline"
    LAST_ERR=""
    for i in $(seq 1 40); do
      LAST_ERR=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
        --query "InstanceInformationList[0].PingStatus" --output text --region "$REGION" 2>&1)
      STATUS="$LAST_ERR"
      [ "$STATUS" = "Online" ] && break
      case "$LAST_ERR" in
        *"An error occurred"*|*"Unable to locate credentials"*)
          echo "aws cli call failed (not just 'not yet online'):"
          echo "$LAST_ERR"
          exit 1
          ;;
      esac
      sleep 15
    done

    if [ "$STATUS" != "Online" ]; then
      echo "=================================================================="
      echo "EC2 instance $INSTANCE_ID never registered with SSM in region $REGION."
      echo "Last describe-instance-information output/error:"
      echo "$LAST_ERR"
      echo "------------------------------------------------------------------"
      echo "Caller identity (credentials being used to run terraform):"
      aws sts get-caller-identity --region "$REGION" || true
      echo "------------------------------------------------------------------"
      echo "Instance state / IAM profile / subnet:"
      aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
        --query "Reservations[0].Instances[0].{State:State.Name,Profile:IamInstanceProfile.Arn,Subnet:SubnetId,SG:SecurityGroups}" \
        --output json || true
      SUBNET_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
        --query "Reservations[0].Instances[0].SubnetId" --output text 2>/dev/null || echo "")
      echo "------------------------------------------------------------------"
      echo "Route table for that subnet (need a 0.0.0.0/0 -> nat-... route, State=active):"
      aws ec2 describe-route-tables --region "$REGION" \
        --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
        --query "RouteTables[].Routes" --output json || true
      echo "------------------------------------------------------------------"
      echo "NAT Gateways (should be State=available):"
      aws ec2 describe-nat-gateways --region "$REGION" \
        --query "NatGateways[].{State:State,SubnetId:SubnetId,NatGatewayId:NatGatewayId}" --output json || true
      echo "------------------------------------------------------------------"
      echo "EC2 console output (last boot log, may show cloud-init/network errors):"
      aws ec2 get-console-output --instance-id "$INSTANCE_ID" --region "$REGION" \
        --query "Output" --output text 2>/dev/null | tail -60 || true
      echo "=================================================================="
      exit 1
    fi

    COMMAND_ID=$(aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters "file://${local.params_path}" \
      --query "Command.CommandId" --output text --region "$REGION")

    echo "Waiting for SSM command $COMMAND_ID to finish..."
    CMD_STATUS="Pending"
    for i in $(seq 1 40); do
      CMD_STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
        --query "Status" --output text --region "$REGION" 2>/dev/null || echo "Pending")
      if [ "$CMD_STATUS" = "Success" ] || [ "$CMD_STATUS" = "Failed" ]; then
        break
      fi
      sleep 15
    done

    aws ssm get-command-invocation \
      --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
      --region "$REGION"

    if [ "$CMD_STATUS" != "Success" ]; then
      echo "Topic creation command did not succeed: $CMD_STATUS"
      exit 1
    fi
  EOT

  ps_script = <<-EOT
    $ErrorActionPreference = "Stop"
    $InstanceId = "${var.ec2_instance_id}"
    $Region = "${var.region}"

    Write-Host "Waiting for SSM agent to come online on $InstanceId..."
    $Status = "Offline"
    for ($i = 0; $i -lt 40; $i++) {
      $Status = aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$InstanceId" --query "InstanceInformationList[0].PingStatus" --output text --region $Region 2>&1
      if ($Status -eq "Online") { break }
      if ($Status -match "An error occurred" -or $Status -match "Unable to locate credentials") {
        Write-Host "aws cli call failed (not just 'not yet online'):"
        Write-Host $Status
        exit 1
      }
      Start-Sleep -Seconds 15
    }

    if ($Status -ne "Online") {
      Write-Host "=================================================================="
      Write-Host "EC2 instance $InstanceId never registered with SSM in region $Region."
      Write-Host "Last describe-instance-information output/error:"
      Write-Host $Status
      Write-Host "------------------------------------------------------------------"
      Write-Host "Caller identity (credentials being used to run terraform):"
      aws sts get-caller-identity --region $Region
      Write-Host "------------------------------------------------------------------"
      Write-Host "Instance state / IAM profile / subnet:"
      aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].{State:State.Name,Profile:IamInstanceProfile.Arn,Subnet:SubnetId,SG:SecurityGroups}" --output json
      $SubnetId = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].SubnetId" --output text
      Write-Host "------------------------------------------------------------------"
      Write-Host "Route table for that subnet (need a 0.0.0.0/0 -> nat-... route, State=active):"
      aws ec2 describe-route-tables --region $Region --filters "Name=association.subnet-id,Values=$SubnetId" --query "RouteTables[].Routes" --output json
      Write-Host "------------------------------------------------------------------"
      Write-Host "NAT Gateways (should be State=available):"
      aws ec2 describe-nat-gateways --region $Region --query "NatGateways[].{State:State,SubnetId:SubnetId,NatGatewayId:NatGatewayId}" --output json
      Write-Host "------------------------------------------------------------------"
      Write-Host "EC2 console output (last boot log, may show cloud-init/network errors):"
      $Console = aws ec2 get-console-output --instance-id $InstanceId --region $Region --query "Output" --output text
      if ($Console) { ($Console -split "`n") | Select-Object -Last 60 }
      Write-Host "=================================================================="
      exit 1
    }

    $CommandId = aws ssm send-command --instance-ids $InstanceId --document-name "AWS-RunShellScript" --parameters "file://${local.params_path}" --query "Command.CommandId" --output text --region $Region

    Write-Host "Waiting for SSM command $CommandId to finish..."
    $CmdStatus = "Pending"
    for ($i = 0; $i -lt 40; $i++) {
      $CmdStatus = aws ssm get-command-invocation --command-id $CommandId --instance-id $InstanceId --query "Status" --output text --region $Region 2>$null
      if ($CmdStatus -eq "Success" -or $CmdStatus -eq "Failed") { break }
      Start-Sleep -Seconds 15
    }

    aws ssm get-command-invocation --command-id $CommandId --instance-id $InstanceId --region $Region

    if ($CmdStatus -ne "Success") {
      Write-Error "Topic creation command did not succeed: $CmdStatus"
      exit 1
    }
  EOT
}

resource "local_file" "ssm_params" {
  count    = var.create ? 1 : 0
  filename = "${path.module}/build/ssm_params_${var.raw_topic_name}.json"
  content = jsonencode({
    commands = ["echo ${local.remote_cmd_b64} | base64 -d | bash"]
  })
}

resource "null_resource" "create_topics" {
  count = var.create ? 1 : 0

  triggers = {
    instance_id            = var.ec2_instance_id
    raw_topic_name         = var.raw_topic_name
    raw_topic_partitions   = var.raw_topic_partitions
    raw_topic_rf           = var.raw_topic_replication_factor
    alert_topic_name       = var.alert_topic_name
    alert_topic_partitions = var.alert_topic_partitions
    alert_topic_rf         = var.alert_topic_replication_factor
  }

  provisioner "local-exec" {
    interpreter = local.is_windows ? ["PowerShell", "-NoProfile", "-Command"] : ["/bin/bash", "-c"]
    command     = local.is_windows ? local.ps_script : local.bash_script
  }

  depends_on = [local_file.ssm_params]
}
