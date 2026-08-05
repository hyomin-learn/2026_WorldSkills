data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/index.py"
  output_path = "${path.module}/build/lambda-score.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      S3_BUCKET = var.s3_bucket
      DDB_TABLE = var.ddb_table
    }
  }
}
