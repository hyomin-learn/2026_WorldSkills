resource "aws_secretsmanager_secret" "docdb" {
  name       = "skills-nosql-docdb-secret"
  kms_key_id = var.kms_key_arn
}

resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id = aws_secretsmanager_secret.docdb.id
  secret_string = jsonencode({
    username = var.username
    password = var.password
    host     = var.docdb_host
  })
}
