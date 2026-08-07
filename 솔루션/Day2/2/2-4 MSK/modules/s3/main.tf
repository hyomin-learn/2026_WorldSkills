resource "aws_s3_bucket" "alert" {
  bucket = "${var.project}-sensor-alert-bucket-${var.student_id}"

  tags = {
    Name = "${var.project}-sensor-alert-bucket-${var.student_id}"
  }
}

resource "aws_s3_bucket_public_access_block" "alert" {
  bucket = aws_s3_bucket.alert.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "alert" {
  bucket = aws_s3_bucket.alert.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_object" "app_binary" {
  bucket = aws_s3_bucket.alert.id
  key    = "deploy/app"
  source = "${path.module}/files/app"
  etag   = filemd5("${path.module}/files/app")
}
