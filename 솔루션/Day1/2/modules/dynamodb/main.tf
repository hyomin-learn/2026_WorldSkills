data "aws_caller_identity" "current" {}

# --------------------------- CMK: alias/wskorea26-dynamodb-key ---------------------------
data "aws_iam_policy_document" "db_key" {
  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowDynamoDBService"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.ap-northeast-2.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "db" {
  description             = "CMK for ${var.table_name} DynamoDB table"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.db_key.json
  tags                    = { Name = "${var.project}-dynamodb-key" }
}

resource "aws_kms_alias" "db" {
  name          = "alias/${var.project}-dynamodb-key"
  target_key_id = aws_kms_key.db.key_id
}

# --------------------------- Table: wskorea26-data-table ---------------------------
# Primary Key : client_id(S)
# Lambda 의 concert_name 조회 + 최신순 정렬(created_at)을 DB 레벨에서 처리하기 위한 GSI
resource "aws_dynamodb_table" "data" {
  name                        = var.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "client_id"
  deletion_protection_enabled = true

  attribute {
    name = "client_id"
    type = "S"
  }

  attribute {
    name = "concert_name"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "concert_name-created_at-index"
    hash_key        = "concert_name"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.db.arn
  }

  tags = { Name = var.table_name }
}

# --------------------------- IAM Policy : book 애플리케이션 쓰기 권한 ---------------------------
data "aws_iam_policy_document" "book_write" {
  statement {
    sid    = "BookTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.data.arn,
      "${aws_dynamodb_table.data.arn}/index/*",
    ]
  }

  statement {
    sid    = "BookTableKmsUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.db.arn]
  }
}

resource "aws_iam_policy" "book_write" {
  name        = "${var.project}-book-dynamodb-write"
  description = "book 애플리케이션 파드에 부여할 wskorea26-data-table 읽기/쓰기 권한"
  policy      = data.aws_iam_policy_document.book_write.json
}
