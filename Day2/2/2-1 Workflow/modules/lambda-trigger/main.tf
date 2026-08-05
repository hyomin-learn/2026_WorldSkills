data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/index.py"
  output_path = "${path.module}/build/lambda-trigger.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      STATE_MACHINE_ARN = var.state_machine_arn
    }
  }
}
