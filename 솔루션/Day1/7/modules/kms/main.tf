data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.statements
    content {
      sid    = try(statement.value.sid, null)
      effect = statement.value.effect

      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = statement.value.principals != null ? [statement.value.principals] : []
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_kms_key" "this" {
  key_usage               = var.key_usage
  deletion_window_in_days = var.deletion_window_in_days
  rotation_period_in_days = var.rotation_period_in_days
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = var.multi_region
  policy = data.aws_iam_policy_document.this.json

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  target_key_id          = aws_kms_key.this.key_id
  name                   = var.alias_name
}

resource "aws_kms_replica_key" "this" {
  provider = aws.ap_northeast_2

  count = var.multi_region ? 1 : 0
  region                  = var.replica_region
  deletion_window_in_days = var.deletion_window_in_days
  primary_key_arn         = aws_kms_key.this.arn
  policy                  = data.aws_iam_policy_document.this.json


  tags = var.tags
}

resource "aws_kms_alias" "this_replica" {
  provider = aws.ap_northeast_2

  count         = var.multi_region ? 1 : 0

  name          = var.replica_alias_name
  target_key_id = aws_kms_replica_key.this[0].key_id
}