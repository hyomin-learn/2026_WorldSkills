output "bucket_name" {
  value = aws_s3_bucket.artifacts.id
}

output "object_keys" {
  value = [for o in aws_s3_object.kubernetes : o.key]
}
