data "aws_iam_policy_document" "this_role" {
  dynamic "statement" {
    for_each = var.role_statements
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

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.this_role.json
}

data "aws_iam_policy_document" "this_policy" {
  dynamic "statement" {
    for_each = var.policy_statements
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


resource "aws_iam_policy" "this" {
  count  = var.enable_custom_policy ? 1 : 0

  name   = var.policy_name
  policy = data.aws_iam_policy_document.this_policy.json
  tags   = var.policy_tags
}

resource "aws_iam_role_policy" "inline" {
  count  = var.enable_inline_policy ? 1 : 0

  name   = var.inline_policy_name
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.this_policy.json
}

resource "aws_iam_role_policy_attachment" "custom" {
  count      = var.enable_custom_policy ? 1 : 0
  
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.enable_managed_policy ? { for p in var.managed_policy_arns : p => p } : {}

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
