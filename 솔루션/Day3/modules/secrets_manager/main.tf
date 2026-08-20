resource "aws_secretsmanager_secret" "rds" {
  name                    = "apdev-rds-secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    MYSQL_USER     = var.db_username
    MYSQL_PASSWORD = var.db_password
    MYSQL_HOST     = var.db_host
    MYSQL_PORT     = var.db_port
    MYSQL_DBNAME   = var.db_dbname
  })
}

resource "aws_secretsmanager_secret" "proxy" {
  name                    = "apdev-rds-proxy-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "proxy" {
  secret_id = aws_secretsmanager_secret.proxy.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}