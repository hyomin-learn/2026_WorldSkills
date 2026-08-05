data "archive_file" "src" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/${var.function_name}.zip"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# 9. Lambda Function : 최소 권한 원칙
#   - wskorea26-data-table 의 GSI 조회(Query)만 허용
#   - CMK(wskorea26-dynamodb-key) 복호화만 허용
#   - 로그 전송 기본 권한만 허용
data "aws_iam_policy_document" "policy" {
  statement {
    sid       = "QueryReservations"
    effect    = "Allow"
    actions   = ["dynamodb:Query"]
    resources = ["${var.table_arn}/index/${var.gsi_name}"]
  }
  statement {
    sid       = "KmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.db_kms_key_arn]
  }
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.policy.json
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role              = aws_iam_role.lambda.arn
  runtime           = var.runtime
  handler           = "handler.handler"
  filename          = data.archive_file.src.output_path
  source_code_hash  = data.archive_file.src.output_base64sha256
  timeout           = 15
  memory_size       = 256

  environment {
    variables = {
      TABLE_NAME = var.table_name
      GSI_NAME   = var.gsi_name
    }
  }
}
