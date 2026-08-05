output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "stepfunction_role_arn" {
  value = aws_iam_role.stepfunction_role.arn
}
