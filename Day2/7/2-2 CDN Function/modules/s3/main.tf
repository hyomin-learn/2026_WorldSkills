data "aws_caller_identity" "current" {}

locals {
  # 버킷명 : skillsphone-landing-ab-<ACCOUNT_ID 12자리>
  bucket_name = "${var.project}-landing-ab-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

# 모든 Public Access 차단 (CloudFront OAC 를 통해서만 접근)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# index_a.html -> /version-a/index.html
resource "aws_s3_object" "version_a" {
  bucket       = aws_s3_bucket.this.id
  key          = "version-a/index.html"
  source       = "${path.module}/../../app/index_a.html"
  etag         = filemd5("${path.module}/../../app/index_a.html")
  content_type = "text/html"
}

# index_b.html -> /version-b/index.html
resource "aws_s3_object" "version_b" {
  bucket       = aws_s3_bucket.this.id
  key          = "version-b/index.html"
  source       = "${path.module}/../../app/index_b.html"
  etag         = filemd5("${path.module}/../../app/index_b.html")
  content_type = "text/html"
}
