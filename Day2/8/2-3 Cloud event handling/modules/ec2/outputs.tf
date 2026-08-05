output "security_group_id" {
  value = aws_security_group.protected.id
}

output "instance_id" {
  value = aws_instance.this.id
}
