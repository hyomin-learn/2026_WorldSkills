output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "kvs_name" {
  value = aws_cloudfront_key_value_store.ab.name
}
