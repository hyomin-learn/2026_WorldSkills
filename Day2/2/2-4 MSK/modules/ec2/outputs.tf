output "instance_id" {
  value = aws_instance.producer.id
}

output "iam_role_name" {
  value = aws_iam_role.ec2_role.name
}

output "security_group_id" {
  value = var.security_group_id
}
