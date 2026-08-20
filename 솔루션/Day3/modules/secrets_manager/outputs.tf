output "secret_arn" {
  value = aws_secretsmanager_secret.rds.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.rds.name
}

output "proxy_secret_arn" {
  value = aws_secretsmanager_secret.proxy.arn
}

output "proxy_secret_name" {
  value = aws_secretsmanager_secret.proxy.name
}