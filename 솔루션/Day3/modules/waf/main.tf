resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.enable_cloudfront ? "CLOUDFRONT" : "REGIONAL"

  dynamic "custom_response_body" {
    for_each = var.custom_response_body != "" && var.custom_response_body != null ? [1] : []
    content {
      key          = var.custom_response_key
      content      = var.custom_response_body
      content_type = "TEXT_PLAIN"
    }
  }

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {
        dynamic "custom_response" {
          for_each = var.default_block_response != null ? [1] : []
          content {
            response_code            = var.default_block_response
            custom_response_body_key = var.custom_response_body != "" && var.custom_response_body != null ? "custom-block-response" : null
          }
        }
      }
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = var.metric_name
  }

  dynamic "rule" {
    for_each = var.enable_managed ? { for idx, r in var.managed_rules : r.name => r if r.enabled } : {}
    content {
      name     = rule.value.name
      priority = 10 + index(var.managed_rules, rule.value)

      override_action {
        none {}
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.metric_name}-${rule.value.name}"
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_group
          vendor_name = rule.value.vendor
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.enable_custom ? { for idx, r in var.custom_rules : r.name => r if r.enabled } : {}
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            dynamic "custom_response" {
              for_each = rule.value.enable_custom_response ? [1] : []
              content {
                response_code            = rule.value.custom_response_code
                custom_response_body_key = rule.value.custom_response_body_key
              }
            }
          }
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.metric_name}-${rule.value.name}"
      }

      statement {
        dynamic "rate_based_statement" {
          for_each = rule.value.type == "RATE_BASED" ? [1] : []
          content {
            limit              = rule.value.limit
            aggregate_key_type = rule.value.aggregate_key
            evaluation_window_sec = rule.value.evaluation_window_sec
          }
        }

        dynamic "and_statement" {
          for_each = rule.value.type == "AND" ? [1] : []
          content {
            dynamic "statement" {
              for_each = rule.value.statements
              content {
                byte_match_statement {
                  search_string         = statement.value.search_string
                  positional_constraint = statement.value.positional_constraint

                  field_to_match {
                    dynamic "method" {
                      for_each = statement.value.field == "method" ? [1] : []
                      content {}
                    }
                    dynamic "uri_path" {
                      for_each = statement.value.field == "uri_path" ? [1] : []
                      content {}
                    }
                    dynamic "query_string" {
                      for_each = statement.value.field == "query_string" ? [1] : []
                      content {}
                    }
                    dynamic "body" {
                      for_each = statement.value.field == "body" ? [1] : []
                      content { oversize_handling = "CONTINUE" }
                    }
                    dynamic "json_body" {
                      for_each = statement.value.field == "json_body" ? [1] : []

                      content {
                        match_scope               = "KEY"
                        invalid_fallback_behavior = "NO_MATCH"
                        oversize_handling         = "NO_MATCH"

                        match_pattern {
                          all {}
                        }
                      }
                    }
                  }

                  text_transformation {
                    priority = 0
                    type     = statement.value.field == "method" ? "NONE" : "LOWERCASE"
                  }
                }
              }
            }
          }
        }

        dynamic "or_statement" {
          for_each = rule.value.type == "OR" ? [1] : []
          content {
            dynamic "statement" {
              for_each = rule.value.statements
              content {
                byte_match_statement {
                  search_string         = statement.value.search_string
                  positional_constraint = statement.value.positional_constraint

                  field_to_match {
                    dynamic "method" {
                      for_each = statement.value.field == "method" ? [1] : []
                      content {}
                    }
                    dynamic "uri_path" {
                      for_each = statement.value.field == "uri_path" ? [1] : []
                      content {}
                    }
                    dynamic "query_string" {
                      for_each = statement.value.field == "query_string" ? [1] : []
                      content {}
                    }
                    dynamic "body" {
                      for_each = statement.value.field == "body" ? [1] : []
                      content { oversize_handling = "CONTINUE" }
                    }
                    dynamic "json_body" {
                      for_each = statement.value.field == "json_body" ? [1] : []

                      content {
                        match_scope               = "KEY"
                        invalid_fallback_behavior = "NO_MATCH"
                        oversize_handling         = "NO_MATCH"

                        match_pattern {
                          all {}
                        }
                      }
                    }
                  }

                  text_transformation {
                    priority = 0
                    type     = statement.value.field == "method" ? "NONE" : "LOWERCASE"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.enable_cloudfront || var.alb_arn == null ? 0 : 1

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = (var.enable_logging && length(coalesce(var.log_destination_arns, [])) > 0) ? 1 : 0

  resource_arn = aws_wafv2_web_acl.this.arn
  log_destination_configs = coalesce(var.log_destination_arns, [])
}