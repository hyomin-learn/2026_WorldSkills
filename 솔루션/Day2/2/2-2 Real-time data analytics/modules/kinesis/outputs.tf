output "stream_name" {
  value = aws_kinesis_stream.order.name
}

output "stream_arn" {
  value = aws_kinesis_stream.order.arn
}
