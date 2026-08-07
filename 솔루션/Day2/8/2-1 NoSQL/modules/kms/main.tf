resource "aws_kms_key" "docdb" {
  description             = "KMS key for ${var.project} DocumentDB storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "docdb" {
  name          = "alias/${var.project}-docdb"
  target_key_id = aws_kms_key.docdb.key_id
}
