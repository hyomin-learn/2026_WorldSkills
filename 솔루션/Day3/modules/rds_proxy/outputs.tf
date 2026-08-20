output "host" {
  value = aws_db_proxy.this.endpoint
}

output "security_group_id" {
  value = aws_security_group.this.id
}