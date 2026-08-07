output "test_url" {
  description = "동작 확인용 URL (쿠키 없이 접속 시 weight 비율로 A/B 할당)"
  value       = "https://${module.cloudfront.domain_name}/"
}
