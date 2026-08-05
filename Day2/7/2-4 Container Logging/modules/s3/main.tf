# 배포 아티팩트(kubernetes/ 폴더)를 담는 버킷. Bastion 이 부팅 시 받아갑니다.
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${var.project}-artifacts" }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# kubernetes/ 폴더 전체를 객체로 업로드 (확장자별 content_type 매핑)
locals {
  k8s_files = fileset(var.kubernetes_dir, "**")
  content_types = {
    yaml = "text/yaml"
    yml  = "text/yaml"
    sh   = "text/x-shellscript"
    md   = "text/markdown"
    json = "application/json"
  }
}

resource "aws_s3_object" "kubernetes" {
  for_each = local.k8s_files

  bucket = aws_s3_bucket.artifacts.id
  key    = "kubernetes/${each.value}"
  source = "${var.kubernetes_dir}/${each.value}"
  etag   = filemd5("${var.kubernetes_dir}/${each.value}")

  content_type = lookup(
    local.content_types,
    try(element(split(".", each.value), length(split(".", each.value)) - 1), ""),
    "application/octet-stream"
  )
}
