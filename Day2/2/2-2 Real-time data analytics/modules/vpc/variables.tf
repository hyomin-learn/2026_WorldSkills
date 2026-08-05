variable "project" {
  type = string
}

variable "vpc_cidr" {
  description = "analytics-vpc CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs for a/b subnets"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "app_port" {
  description = "Port the Flask/Gunicorn app listens on (Application.md => 5000)"
  type        = number
  default     = 5000
}
