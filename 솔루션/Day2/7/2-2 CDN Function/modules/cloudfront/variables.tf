variable "project" {
  description = "리소스 이름 prefix"
  type        = string
}

variable "bucket_id" {
  description = "정적 콘텐츠 S3 버킷 ID (버킷 정책 적용 대상)"
  type        = string
}

variable "bucket_arn" {
  description = "정적 콘텐츠 S3 버킷 ARN"
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "S3 버킷 리전 도메인 (CloudFront 오리진 도메인)"
  type        = string
}
