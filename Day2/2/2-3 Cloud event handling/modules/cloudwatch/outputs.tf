output "cloudtrail_name" {
  value = aws_cloudtrail.event.name
}

output "eventbridge_rule_names" {
  value = { for k, v in aws_cloudwatch_event_rule.rule : k => v.name }
}
