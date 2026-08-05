output "function_names" {
  value = [
    aws_lambda_function.sensor_consumer.function_name,
    aws_lambda_function.alert_consumer.function_name,
  ]
}

output "iam_role_name" {
  value = aws_iam_role.lambda_role.name
}
