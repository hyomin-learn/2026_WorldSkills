data "aws_caller_identity" "current" {}
resource "aws_s3_bucket" "this" {
  bucket = "apdev-hyomin-bucket"

  tags = {
    Name = "apdev-hyomin-bucket"
  }
}

resource "aws_s3_object" "this" {
  bucket       = aws_s3_bucket.this.bucket
  key          = "images/"
  content_type = "application/x-directory"
}

resource "aws_s3_bucket" "cloudfront_bucket" {
  bucket = "apdev-cloudfront-hyomin-bucket"

  tags = {
    Name = "apdev-cloudfront-hyomin-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_bucket" {
  bucket = aws_s3_bucket.cloudfront_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.cloudfront_bucket
  ]

  bucket = aws_s3_bucket.cloudfront_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "logs" {
  bucket        = "apdev-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "apdev-logs-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  acl        = "log-delivery-write"
}
