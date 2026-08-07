output "sns_topic_arn" {
  value = aws_sns_topic.alert.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "function_arns" {
  description = "Map keyed by sg/stop/terminate/tag"
  value       = { for k, v in aws_lambda_function.fn : k => v.arn }
}

output "function_names" {
  description = "Map keyed by sg/stop/terminate/tag"
  value       = { for k, v in aws_lambda_function.fn : k => v.function_name }
}
