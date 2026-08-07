resource "aws_iam_role" "this" {
  count = var.enable_iam_role ? 1 : 0

  name               = var.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  tags = var.iam_role_tags
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
      
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
  count  = var.enable_iam_role ? 1 : 0

  name   = var.policy_name
  policy = data.aws_iam_policy_document.this.json
  tags   = var.policy_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = var.enable_iam_role ? 1 : 0
  
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_flow_log" "this" {
  iam_role_arn         = var.enable_iam_role ? aws_iam_role.this[0].arn : null
  log_destination_type = var.log_destination_type
  log_destination      = var.log_destination_arn
  log_format           = var.log_format
  traffic_type         = var.traffic_type
  vpc_id               = var.vpc_id

  tags = var.tags
}