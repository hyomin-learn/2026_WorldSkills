output "key_arn" {
  value = aws_kms_key.docdb.arn
}

output "key_id" {
  value = aws_kms_key.docdb.key_id
}
