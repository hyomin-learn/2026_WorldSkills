output "lambda_arn" {
  value = aws_lambda_function.remediate.arn
}

output "function_name" {
  value = aws_lambda_function.remediate.function_name
}
