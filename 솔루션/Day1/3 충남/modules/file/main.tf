resource "random_string" "this" {
  length  = 4
  upper   = false
  lower   = false
  numeric = true
  special = false
}

resource "aws_s3_bucket" "this" {
  bucket        = "wsc-image-${random_string.this.result}"
  force_destroy = true
}

resource "null_resource" "ecr" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/ecr/ s3://${aws_s3_bucket.this.id}/ecr/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "eks" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/eks/ s3://${aws_s3_bucket.this.id}/eks/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../src/scripts/ s3://${aws_s3_bucket.this.id}/scripts/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}