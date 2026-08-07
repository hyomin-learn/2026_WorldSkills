output "bucket_id" {
  value = aws_s3_bucket.alert.id
}

output "bucket_arn" {
  value = aws_s3_bucket.alert.arn
}

output "app_object_key" {
  value = aws_s3_object.app_binary.key
}
