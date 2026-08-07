resource "aws_s3_bucket" "this" {
  bucket   = var.name

  tags = var.tags
}
    
resource "aws_s3_object" "this" {
  for_each = var.enable_objects ? local.processed_objects : {}

  bucket       = aws_s3_bucket.this.id
  key          = each.value.key
  source       = "${path.module}/../../src/${each.value.source}"
  source_hash  = filemd5("${path.module}/../../src/${each.value.source}")
  content_type = each.value.content_type
  server_side_encryption = "aws:kms"
  kms_key_id   = var.enable_object_kms ? var.kms_arn : null
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_arn != null ? var.kms_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.block_public_access ? 1 : 0

  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}