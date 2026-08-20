resource "random_string" "this" {
  length  = 4
  upper   = false
  lower   = false
  numeric = true
  special = false
}

resource "aws_s3_bucket" "this" {
  bucket        = "apdev-image-${random_string.this.result}"
  force_destroy = true
}

# NOTE(수정): 예전에는 여기서 apply할 때마다 PowerShell local-exec로
# apdev-rds-secrets / apdev-rds-proxy-secret 을 강제 삭제(force-delete-without-recovery)
# 하고 있었습니다. 이 로직은 module.secrets_manager의 실제 시크릿 리소스와
# depends_on으로 묶여있지 않아 순서 보장이 안 됐고, triggers=timestamp()라서
# apply할 때마다 무조건 실행되어 "터라폼이 관리 중인 시크릿을 apply 도중
# 스스로 삭제해버리는" 문제를 일으켰습니다 (EC2 부팅 시 rds-setup.sh가
# 시크릿을 못 찾는 사고, terraform plan에서 "changed outside of Terraform"
# drift로 나타나는 문제의 원인이었음).
#
# 대신 modules/secrets_manager/main.tf 의 aws_secretsmanager_secret 리소스에
# recovery_window_in_days = 0 을 설정해서, terraform이 그 리소스를 destroy/replace할
# 때 AWS가 즉시 완전삭제하도록 했습니다. 이러면 "이름이 복구 대기 상태라 재생성이
# 막히는" 문제를 별도의 수동 삭제 로직 없이 terraform 기본 기능만으로 해결됩니다.

resource "null_resource" "rds" {
  depends_on = [aws_s3_bucket.this]

  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/rds/ s3://${aws_s3_bucket.this.bucket}/rds/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "ecr" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/ecr/ s3://${aws_s3_bucket.this.id}/ecr/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "eks" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/eks/ s3://${aws_s3_bucket.this.id}/eks/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/scripts/ s3://${aws_s3_bucket.this.id}/scripts/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}