output "bucket_name" {
  value = aws_s3_bucket.concert.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.concert.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.concert.bucket_regional_domain_name
}

output "s3_kms_key_arn" {
  value = aws_kms_key.s3.arn
}

output "s3_kms_alias" {
  value = aws_kms_alias.s3.name
}
