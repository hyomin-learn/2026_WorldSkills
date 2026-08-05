variable "project" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

# Reference01 그대로: c, d 서브넷 (AZ: ap-northeast-2c / 2d)
variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    c = { cidr = "172.16.1.0/24", az = "ap-northeast-2c" }
    d = { cidr = "172.16.2.0/24", az = "ap-northeast-2d" }
  }
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    c = { cidr = "172.16.201.0/24", az = "ap-northeast-2c" }
    d = { cidr = "172.16.202.0/24", az = "ap-northeast-2d" }
  }
}
