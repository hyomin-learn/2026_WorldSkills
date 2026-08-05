resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "input_folder" {
  bucket  = aws_s3_bucket.this.id
  key     = "input/"
  content = ""
}

resource "aws_s3_object" "processed_folder" {
  bucket  = aws_s3_bucket.this.id
  key     = "processed/"
  content = ""
}

resource "aws_s3_object" "error_folder" {
  bucket  = aws_s3_bucket.this.id
  key     = "error/"
  content = ""
}
