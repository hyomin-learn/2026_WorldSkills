output "ec2_sg_id" {
  value = aws_security_group.ec2.id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "msk_sg_id" {
  value = aws_security_group.msk.id
}
