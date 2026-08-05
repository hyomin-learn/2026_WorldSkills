variable "project" {
  type = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.11.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones (ap-southeast-1)"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public CIDR block list (2)"
  type        = list(string)
  default     = ["10.11.0.0/24", "10.11.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private Subnet CIDR block list (2)"
  type        = list(string)
  default     = ["10.11.10.0/24", "10.11.11.0/24"]
}
