output "table_name" {
  value = aws_dynamodb_table.data.name
}

output "table_arn" {
  value = aws_dynamodb_table.data.arn
}

output "gsi_name" {
  value = "concert_name-created_at-index"
}

output "db_kms_key_arn" {
  value = aws_kms_key.db.arn
}

output "db_kms_alias" {
  value = aws_kms_alias.db.name
}

output "book_write_policy_arn" {
  value = aws_iam_policy.book_write.arn
}
