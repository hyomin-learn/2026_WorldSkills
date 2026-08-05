resource "aws_s3_bucket" "this" {
  bucket   = var.name

  tags = var.tags
}

resource "aws_s3_object" "this" {
  for_each = var.enable_objects ? local.processed_objects : {}

  bucket                 = aws_s3_bucket.this.id
  key                    = each.value.key
  source                 = each.value.source != null ? "${path.module}/../../src/${each.value.source}" : null
  content                = each.value.source == null ? "" : null
  source_hash            = each.value.source != null ? filemd5("${path.module}/../../src/${each.value.source}") : md5("")
  content_type           = each.value.content_type
  server_side_encryption = try(var.server_side_encryption, "AES256")
  kms_key_id             = try(var.kms_arn, null)
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.enable_bucket_kms ? 1 : 0
  
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.server_side_encryption != "AES256" ? var.server_side_encryption : "AES256"
      kms_master_key_id = var.kms_arn
    }
    bucket_key_enabled = var.enable_bucket_kms
  }
}