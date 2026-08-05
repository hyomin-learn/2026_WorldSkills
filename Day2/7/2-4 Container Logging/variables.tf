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

# 선수 등록번호. Grafana 관리자 계정(skills<번호> / GoodJob!Skills<번호>^^)에 사용.
# default 가 없으므로 apply 시 값을 입력받습니다.
variable "competitor_number" {
  description = "선수 등록번호 (예: 53)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.competitor_number))
    error_message = "선수 등록번호는 숫자만 입력하세요 (예: 53)."
  }
}

# true(기본): apply 후 Bastion 이 EKS 생성 + 워크로드 배포까지 자동 수행
# false: 인프라만 만들고 클러스터/배포는 수동(00-create-cluster.sh, deploy.sh)
variable "auto_deploy" {
  description = "Bastion 부팅 시 EKS 생성 + 워크로드 배포 자동 실행 여부"
  type        = bool
  default     = true
}
