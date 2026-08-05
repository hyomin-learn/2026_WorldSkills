variable "project" {
  description = "project-name"
  type        = string
  default     = "wskorea26"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "exam_number" {
  description = "비번호 입력."
  type        = string

  validation {
    condition     = length(trimspace(var.exam_number)) > 0
    error_message = "비번호 다시 입력."
  }
}

variable "grafana_admin_password" {
  description = "Grafana Password"
  type        = string
  default     = "\\$korea26!!"
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "Bastion SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_pair_name" {
  description = "Bastion Key Pair"
  type        = string
  default     = "wskorea26-key"
}
