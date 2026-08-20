variable "seoul_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "virginia_region" {
  type    = string
  default = "us-east-1"
}

variable "db_username" {
  type = string
  default = "admin"
}

variable "db_password" {
  type = string
  default = "Skill53##"
  sensitive = true
}