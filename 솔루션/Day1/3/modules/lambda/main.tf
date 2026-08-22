resource "aws_security_group" "this" {
  count = var.enable_vpc_config ? 1 : 0
  name   = var.security_group_name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      protocol    = ingress.value.protocol
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      cidr_blocks = [ingress.value.cidr_block]
    }
  }

  dynamic "egress" {
    for_each = var.egress_ports
    content {
      protocol    = egress.value.protocol
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      cidr_blocks = [egress.value.cidr_block]
    }
  }

  tags = var.security_group_tags
}

resource "aws_iam_role" "this" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = var.enable_lambda_edge ? ["lambda.amazonaws.com", "edgelambda.amazonaws.com"] : ["lambda.amazonaws.com"]
        }
      }
    ]
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
  count       = var.enable_custom_policy ? 1 : 0 

  name        = var.policy_name
  policy      = data.aws_iam_policy_document.this.json
  tags        = var.policy_tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.enable_managed_policy ? toset(var.iam_policies) : []

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = var.enable_custom_policy ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/../../src${var.source_file_path}"
  output_path = "${path.module}/../../src${var.output_file_path}"
}

resource "aws_kms_ciphertext" "this" {
  for_each  = var.enable_environment && (length(var.environment_variables) > 0) ? var.environment_variables : {}
  
  key_id    = var.kms_key_arn
  plaintext = each.value
}

resource "aws_lambda_function" "this" {
  filename = data.archive_file.this.output_path
  function_name = var.name
  role = aws_iam_role.this.arn
  handler = var.handler
  timeout = var.timeout
  source_code_hash = var.enable_upload_zip ? filebase64sha256("${path.module}/../../src${var.output_file_path}") : data.archive_file.this.output_base64sha256 
  runtime = var.runtime
  publish = var.publish
  kms_key_arn = try(var.kms_key_arn, null)

  dynamic "environment" {
    for_each = var.enable_environment && (length(var.environment_variables) > 0) ? [1] : []
    content {
      variables = var.kms_key_arn != null ? {for k, v in var.environment_variables : k => aws_kms_ciphertext.this[k].ciphertext_blob} : var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc_config ? [1] : [] 
    content {
      security_group_ids          = [aws_security_group.this[0].id]
      subnet_ids                  = var.subnet_ids
    }
  }

  dynamic "logging_config" {
    for_each = var.enable_logging ? [true] : []

    content {
      log_group             = var.log_group_name
      log_format            = var.log_format
      application_log_level = var.log_format == "Text" ? null : var.application_log_format
      system_log_level      = var.log_format == "Text" ? null : var.system_log_format
    }
  }

  tags = var.tags
}

resource "aws_lambda_function_url" "this" {
  count = var.enable_lambda_function_url ? 1 : 0

  function_name = aws_lambda_function.this.function_name
  authorization_type = var.lambda_function_url_auth_type
}