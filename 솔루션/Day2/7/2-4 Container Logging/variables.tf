variable "project" {
  description = "Resource name prefix"
  type        = string
  default     = "o11y"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "o11y-cluster"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "competitor_number" {
  description = "선수 등록번호 (예: 53)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.competitor_number))
    error_message = "선수 등록번호는 숫자만 입력하세요 (예: 53)."
  }
}

variable "auto_deploy" {
  description = "Bastion 부팅 시 EKS 생성 + 워크로드 배포 자동 실행 여부"
  type        = bool
  default     = true
}
