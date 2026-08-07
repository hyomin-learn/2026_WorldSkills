variable "project" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name (used for subnet discovery tags)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones (2)"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR list (2)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR list (2)"
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20"]
}
