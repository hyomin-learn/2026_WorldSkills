data "aws_caller_identity" "current" {}

# --------------------------- CMK: alias/wskorea26-s3-key ---------------------------
data "aws_iam_policy_document" "s3_kms" {
  statement {
    sid       = "EnableRoot"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "s3" {
  description             = "CMK for ${var.project} concert S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.s3_kms.json
  tags                    = { Name = "${var.project}-s3-key" }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project}-s3-key"
  target_key_id = aws_kms_key.s3.key_id
}

# --------------------------- Bucket: wskorea26-concert-bucket-<비번호> ---------------------------
resource "aws_s3_bucket" "concert" {
  bucket = "${var.project}-concert-bucket-${var.exam_number}"
  tags   = { Name = "${var.project}-concert-bucket-${var.exam_number}" }
}

resource "aws_s3_bucket_public_access_block" "concert" {
  bucket                  = aws_s3_bucket.concert.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "concert" {
  bucket = aws_s3_bucket.concert.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "concert" {
  bucket = aws_s3_bucket.concert.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# --------------------------- Objects : Object Path /web/main/ ---------------------------
resource "aws_s3_object" "index" {
  bucket                 = aws_s3_bucket.concert.id
  key                    = "web/main/index.html"
  source                 = "${path.module}/files/index.html"
  content_type           = "text/html"
  source_hash            = filemd5("${path.module}/files/index.html")
  server_side_encryption = "aws:kms"
  kms_key_id              = aws_kms_key.s3.arn
  depends_on              = [aws_s3_bucket_server_side_encryption_configuration.concert]
}

resource "aws_s3_object" "main_image" {
  bucket                 = aws_s3_bucket.concert.id
  key                    = "web/main/main.jpeg"
  source                 = "${path.module}/files/main.jpeg"
  content_type           = "image/jpeg"
  source_hash            = filemd5("${path.module}/files/main.jpeg")
  server_side_encryption = "aws:kms"
  kms_key_id              = aws_kms_key.s3.arn
  depends_on              = [aws_s3_bucket_server_side_encryption_configuration.concert]
}

# CloudFront(OAC) 전용 버킷 정책은 배포 ARN 이 필요하므로 루트 main.tf 에서
# module.s3 / module.cloudfront 완료 후 별도 리소스로 부착한다 (순환참조 방지).
