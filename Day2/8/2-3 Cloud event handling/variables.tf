variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "skills-ceh"
}

variable "vpc_cidr" {
  type    = string
  default = "10.73.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.73.1.0/24"
}

variable "az" {
  type    = string
  default = "ap-southeast-1a"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_timeout" {
  type    = number
  default = 30
}
