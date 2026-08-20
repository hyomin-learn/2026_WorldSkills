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
