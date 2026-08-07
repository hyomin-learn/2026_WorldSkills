output "sts_endpoint_id" {
  value = aws_vpc_endpoint.sts.id
}

output "lambda_endpoint_id" {
  value = aws_vpc_endpoint.lambda.id
}
