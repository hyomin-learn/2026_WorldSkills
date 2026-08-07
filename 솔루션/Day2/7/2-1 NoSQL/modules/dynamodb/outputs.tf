output "reservation_table_name" {
  value = aws_dynamodb_table.reservation.name
}

output "reservation_table_arn" {
  value = aws_dynamodb_table.reservation.arn
}

output "reservation_table_stream_arn" {
  value = aws_dynamodb_table.reservation.stream_arn
}

output "audit_table_name" {
  value = aws_dynamodb_table.audit.name
}

output "audit_table_arn" {
  value = aws_dynamodb_table.audit.arn
}

output "gsi_name" {
  value = var.gsi_name
}
