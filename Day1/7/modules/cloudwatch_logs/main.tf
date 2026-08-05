resource "aws_cloudwatch_log_group" "this" {
  name = var.name
  kms_key_id = try(var.kms_key_id, null)
    
  tags = var.tags
}

resource "aws_cloudwatch_log_stream" "this" {
  for_each = var.create_log_stream ? toset(var.log_stream_names) : []

  name           = each.key
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = var.create_metric_filter ? { for mf in var.metric_filters : mf.name => mf } : {}

  name           = each.value.name
  pattern        = each.value.pattern
  log_group_name = aws_cloudwatch_log_group.this.name

  metric_transformation {
    name          = each.value.metric_transformation.name
    namespace     = each.value.metric_transformation.namespace
    value         = each.value.metric_transformation.value
    default_value = each.value.metric_transformation.default_value
    unit          = try(each.value.metric_transformation.unit, "None")
    dimensions    = each.value.metric_transformation.default_value == null ? try(each.value.metric_transformation.dimensions, null) : null
  }
}
