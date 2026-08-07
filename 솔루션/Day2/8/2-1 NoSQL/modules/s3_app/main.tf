resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "app" {
  bucket        = "${var.project}-app-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "docdb_client_py" {
  bucket = aws_s3_bucket.app.id
  key    = "docdb_client.py"
  source = var.docdb_client_py_path
  etag   = filemd5(var.docdb_client_py_path)
}

resource "aws_s3_object" "retail_dataset_json" {
  bucket = aws_s3_bucket.app.id
  key    = "retail_dataset.json"
  source = var.retail_dataset_json_path
  etag   = filemd5(var.retail_dataset_json_path)
}
