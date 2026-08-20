output "username" {
  value = aws_db_instance.this.username
}

output "password" {
  value = aws_db_instance.this.password
}

output "host" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "dbname" {
  value = aws_db_instance.this.db_name
}

output "rds_id" {
  value = aws_db_instance.this.id
}