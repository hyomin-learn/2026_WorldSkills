data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/remediate_security_group.py"
  output_path = "${path.module}/remediate_security_group.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-remediate-fn-role"

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
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-remediate-fn-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "remediate" {
  function_name    = "${var.project}-remediate-fn"
  role             = aws_iam_role.lambda_role.arn
  handler          = "remediate_security_group.lambda_handler"
  runtime          = var.runtime
  timeout          = var.timeout
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      PROTECTED_SECURITY_GROUP_ID = var.security_group_id
      SNS_TOPIC_ARN               = var.sns_topic_arn
    }
  }

  tags = {
    Name = "${var.project}-remediate-fn"
  }
}
