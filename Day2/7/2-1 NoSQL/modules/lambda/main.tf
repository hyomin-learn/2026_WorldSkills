data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# =============== Lambda 실행 역할 ===============
resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.function_name}-role" }
}

resource "aws_iam_role_policy_attachment" "stream" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
}

resource "aws_iam_role_policy" "audit_write" {
  name = "${var.function_name}-audit-write"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = var.audit_table_arn
      }
    ]
  })
}

# =============== Lambda Function ===============
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  runtime          = "python3.13"
  handler          = "lambda_function.handler"
  timeout          = 30
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      AUDIT_TABLE_NAME = var.audit_table_name
    }
  }

  tags = { Name = var.function_name }
}

# =============== DynamoDB Streams -> Lambda 트리거 ===============
resource "aws_lambda_event_source_mapping" "stream" {
  event_source_arn  = var.source_table_stream_arn
  function_name     = aws_lambda_function.this.arn
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true

  depends_on = [aws_iam_role_policy_attachment.stream]
}
